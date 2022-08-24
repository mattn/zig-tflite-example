const std = @import("std");
const cv = @import("zigcv");
const tflite = @import("tflite");
const xnnpack = @import("tflite-xnnpack");
// const edgetpu = @import("tflite-edgetpu");

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    const prog = args.next();
    const deviceIDChar = args.next() orelse {
        std.log.err("usage: {s} [cameraID]", .{prog.?});
        std.os.exit(1);
    };

    // open webcam
    var webcam = cv.VideoCapture_New();

    const deviceID = std.fmt.parseUnsigned(c_int, deviceIDChar, 10) catch -1;
    if (deviceID < 0) {
        _ = cv.VideoCapture_Open(webcam, @ptrCast([*c]const u8, deviceIDChar));
    } else {
        _ = cv.VideoCapture_OpenDevice(webcam, deviceID);
    }

    defer cv.VideoCapture_Close(webcam);

    const window_name = "Object Detection";
    _ = cv.Window_New(window_name, 0);
    defer cv.Window_Close(window_name);

    var img = cv.Mat_New();
    defer cv.Mat_Close(img);

    var resized = cv.Mat_New();
    defer cv.Mat_Close(resized);

    const blue = cv.Scalar{
        .val1 = 255,
        .val2 = 0,
        .val3 = 0,
        .val4 = 0,
    };
    const green = cv.Scalar{
        .val1 = 0,
        .val2 = 255,
        .val3 = 0,
        .val4 = 0,
    };

    var tfm = try tflite.modelFromFile("detect.tflite");
    // var tfm = try tflite.modelFromFile("mobilenet_ssd_v1_coco_quant_postprocess_edgetpu.tflite");
    defer tfm.deinit();

    var tfo = try tflite.interpreterOptions();
    defer tfo.deinit();

    // var devices = std.ArrayList(edgetpu.Device).init(allocator);
    // defer devices.deinit();
    // try edgetpu.listDevices(&devices);
    // if (devices.items.len > 0) {
    //     tfo.addDelegate(edgetpu.EdgeTPU(devices.items[0], 0));
    // }
    tfo.setNumThreads(4);

    var tfi = try tflite.interpreter(tfm, tfo);
    defer tfi.deinit();

    try tfi.allocateTensors();

    var inputTensor = tfi.inputTensor(0);
    var input = inputTensor.data(f32);
    const wanted_width = inputTensor.dim(1);
    const wanted_height = inputTensor.dim(2);
    var locTensor = tfi.outputTensor(0);
    const loc = locTensor.data(f32);
    var classTensor = tfi.outputTensor(1);
    const class = classTensor.data(f32);
    var scoreTensor = tfi.outputTensor(2);
    const score = scoreTensor.data(f32);
    const labels = [_][]const u8{ "???", "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light", "fire hydrant", "???", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "???", "backpack", "umbrella", "???", "???", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle", "???", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch", "potted plant", "bed", "???", "dining table", "???", "???", "toilet", "???", "tv", "laptop", "mouse", "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "???", "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush" };

    const cdsize = cv.Size{ .width = wanted_width, .height = wanted_height };

    while (true) {
        if (cv.VideoCapture_Read(webcam, img) != 1) {
            std.debug.print("capture failed", .{});
            std.os.exit(1);
        }
        if (cv.Mat_Empty(img) == 1) {
            continue;
        }

        cv.Resize(img, resized, cdsize, 0, 0, 1);
        const p = cv.Mat_DataPtr(resized);
        const nv = @intCast(usize, p.length) / @as(usize, 4);
        const ff = @ptrCast([*]f32, @alignCast(@alignOf(f32), p.data))[0..nv];
        std.mem.copy(f32, input, ff);

        try tfi.invoke();

        const cols = @intToFloat(f32, cv.Mat_Cols(img));
        const rows = @intToFloat(f32, cv.Mat_Rows(img));
        var i: usize = 0;
        while (i < score.len) : (i += 1) {
            if (score[i] < 0.6) continue;
            const o = loc[(i * 4)..(i * 4 + 4)];
            const x1 = @floatToInt(c_int, cols * o[1]);
            const y1 = @floatToInt(c_int, rows * o[0]);
            const x2 = @floatToInt(c_int, cols * o[3]);
            const y2 = @floatToInt(c_int, rows * o[2]);
            const r = cv.Rect{
                .x = x1,
                .y = y1,
                .width = x2 - x1,
                .height = y2 - y1,
            };
            cv.Rectangle(img, r, blue, 3);

            const pt = cv.Point{ .x = x1, .y = y1 };
            cv.PutText(img, @ptrCast([*]const u8, labels[@floatToInt(usize, class[i] + 1)]), pt, 0, 1, green, 3);
        }

        _ = cv.Window_IMShow(window_name, img);
        if (cv.Window_WaitKey(1) >= 0) {
            break;
        }
    }
}
