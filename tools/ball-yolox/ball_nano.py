# YOLOX experiment: YOLOX-nano, one class ("ball"), 640 px input for a small ball.
#   python tools/train.py -f <this file> -d 1 -b 32 --fp16 -o -c yolox_nano.pth
# BALL_DATA (env) = the to_coco.py output folder.
import os

import torch.nn as nn

from yolox.exp import Exp as MyExp


class Exp(MyExp):
    def __init__(self):
        super().__init__()
        self.num_classes = 1
        self.depth = 0.33
        self.width = 0.25
        # The ball can be ~15 px across: train and run at 640 rather than nano's usual 416.
        self.input_size = (640, 640)
        self.test_size = (640, 640)
        self.multiscale_range = 3
        self.mosaic_scale = (0.5, 1.5)
        self.mosaic_prob = 0.5
        self.enable_mixup = False
        self.max_epoch = 80
        self.no_aug_epochs = 10
        self.warmup_epochs = 3
        self.eval_interval = 5
        self.data_num_workers = 4
        self.data_dir = os.environ.get("BALL_DATA", "datasets/ball")
        self.train_ann = "instances_train2017.json"
        self.val_ann = "instances_val2017.json"
        self.exp_name = "ball_nano"

    def get_model(self, sublinear=False):
        def init_yolo(module):
            for m in module.modules():
                if isinstance(m, nn.BatchNorm2d):
                    m.eps = 1e-3
                    m.momentum = 0.03

        if "model" not in self.__dict__:
            from yolox.models import YOLOX, YOLOPAFPN, YOLOXHead
            in_channels = [256, 512, 1024]
            backbone = YOLOPAFPN(self.depth, self.width, in_channels=in_channels, act=self.act, depthwise=True)
            head = YOLOXHead(self.num_classes, self.width, in_channels=in_channels, act=self.act, depthwise=True)
            self.model = YOLOX(backbone, head)

        self.model.apply(init_yolo)
        self.model.head.initialize_biases(1e-2)
        return self.model
