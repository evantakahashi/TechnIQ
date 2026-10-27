"""Trained YOLOX checkpoint → BallDetector.mlpackage (Core ML pipeline: detector + NMS), ready for Vision.

    python export_coreml.py -f ball_nano.py -c YOLOX_outputs/ball_nano/best_ckpt.pth -o BallDetector.mlpackage
    # COCO-pretrained check, keeping only "sports ball" (COCO class 32):
    python export_coreml.py -f <YOLOX>/exps/default/yolox_nano.py -c yolox_nano.pth --class-index 32 --size 640 -o x.mlpackage

Vision gets VNRecognizedObjectObservation labelled "ball", with optional `confidenceThreshold` /
`iouThreshold` inputs (FrameAnalyzer sets them), like Create ML and Ultralytics models.
Input: BGR, 0–255, no normalisation (YOLOX's non-legacy preprocessing).
"""
import argparse

import coremltools as ct
import numpy as np
import torch
import torch.nn as nn
from yolox.exp import get_exp


class Detector(nn.Module):
    """YOLOX with decoding on → per-anchor ball scores [N, 1] and normalised centre boxes [N, 4]."""

    def __init__(self, model, size, class_index):
        super().__init__()
        self.model = model
        self.size = float(size)
        self.class_index = class_index

    def forward(self, x):
        out = self.model(x)[0]  # [N, 5 + classes]: cx, cy, w, h (input px), objectness, class scores
        boxes = out[:, :4] / self.size
        cls = out[:, 5:] if self.class_index is None else out[:, 5 + self.class_index:6 + self.class_index]
        return out[:, 4:5] * cls, boxes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-f", "--exp", required=True)
    ap.add_argument("-c", "--ckpt", required=True)
    ap.add_argument("-o", "--out", default="BallDetector.mlpackage")
    ap.add_argument("--size", type=int, default=None, help="input side (default: the exp's test size)")
    ap.add_argument("--class-index", type=int, default=None, help="keep one class of a multi-class model")
    args = ap.parse_args()

    exp = get_exp(args.exp, None)
    size = args.size or exp.test_size[0]
    model = exp.get_model()
    model.load_state_dict(torch.load(args.ckpt, map_location="cpu", weights_only=False)["model"])
    model.eval()
    model.head.decode_in_inference = True
    detector = Detector(model, size, args.class_index).eval()

    example = torch.zeros(1, 3, size, size)
    with torch.no_grad():
        traced = torch.jit.trace(detector, example)
        scores, boxes = traced(example)
    anchors, classes = scores.shape
    print(f"input {size}x{size}, {anchors} anchors, {classes} class(es)")

    detector_model = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=example.shape, color_layout=ct.colorlayout.BGR, scale=1.0)],
        # NMS only takes float32 (iOS 17 programs default to float16 I/O).
        outputs=[ct.TensorType(name="raw_confidence", dtype=np.float32), ct.TensorType(name="raw_coordinates", dtype=np.float32)],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS17,
    )
    spec = detector_model.get_spec()
    out_conf, out_coords = spec.description.output
    out_conf.type.multiArrayType.shape[:] = [anchors, classes]
    out_coords.type.multiArrayType.shape[:] = [anchors, 4]
    detector_model = ct.models.MLModel(spec, weights_dir=detector_model.weights_dir)

    # Non-maximum suppression stage (Vision reads its confidence/coordinates as recognised objects).
    nms_spec = ct.proto.Model_pb2.Model()
    nms_spec.specificationVersion = spec.specificationVersion
    for i, size_last in enumerate([classes, 4]):
        feature = detector_model._spec.description.output[i].SerializeToString()
        nms_spec.description.input.add().ParseFromString(feature)
        out = nms_spec.description.output.add()
        out.ParseFromString(feature)
        out.name = ["confidence", "coordinates"][i]
        ma = out.type.multiArrayType
        del ma.shape[:]
        rng = ma.shapeRange.sizeRanges.add()
        rng.lowerBound, rng.upperBound = 0, -1
        rng = ma.shapeRange.sizeRanges.add()
        rng.lowerBound, rng.upperBound = size_last, size_last
    nms = nms_spec.nonMaximumSuppression
    nms.confidenceInputFeatureName = "raw_confidence"
    nms.coordinatesInputFeatureName = "raw_coordinates"
    nms.confidenceOutputFeatureName = "confidence"
    nms.coordinatesOutputFeatureName = "coordinates"
    nms.iouThresholdInputFeatureName = "iouThreshold"
    nms.confidenceThresholdInputFeatureName = "confidenceThreshold"
    nms.iouThreshold = 0.45
    nms.confidenceThreshold = 0.25
    nms.pickTop.perClass = True
    nms.stringClassLabels.vector.extend(["ball"] * classes)
    nms_model = ct.models.MLModel(nms_spec)

    pipeline = ct.models.pipeline.Pipeline(
        input_features=[
            ("image", ct.models.datatypes.Array(3, size, size)),
            ("iouThreshold", ct.models.datatypes.Double()),
            ("confidenceThreshold", ct.models.datatypes.Double()),
        ],
        output_features=["confidence", "coordinates"],
    )
    pipeline.add_model(detector_model)
    pipeline.add_model(nms_model)
    pipeline.spec.description.input[0].ParseFromString(detector_model._spec.description.input[0].SerializeToString())
    pipeline.spec.description.output[0].ParseFromString(nms_model._spec.description.output[0].SerializeToString())
    pipeline.spec.description.output[1].ParseFromString(nms_model._spec.description.output[1].SerializeToString())
    pipeline.spec.specificationVersion = spec.specificationVersion
    meta = pipeline.spec.description.metadata
    meta.shortDescription = "Soccer ball detector (YOLOX-nano, Apache-2.0)"
    meta.author = "TechnIQ"

    final = ct.models.MLModel(pipeline.spec, weights_dir=detector_model.weights_dir)
    final.input_description["image"] = "Frame, BGR"
    final.input_description["iouThreshold"] = "(optional) IoU threshold override (default 0.45)"
    final.input_description["confidenceThreshold"] = "(optional) Confidence threshold override (default 0.25)"
    final.output_description["confidence"] = "Ball confidence per box"
    final.output_description["coordinates"] = "Boxes: centre x, centre y, width, height (normalised)"
    final.save(args.out)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
