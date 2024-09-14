import os
import argparse
import time

import torch
from safetensors.torch import load_file
from diffusers import StableDiffusionXLPipeline
from onediffx import compile_pipe, save_pipe, load_pipe
from huggingface_hub import hf_hub_download

parser = argparse.ArgumentParser()
parser.add_argument(
    "--base", type=str, default="stabilityai/stable-diffusion-xl-base-1.0"
)
parser.add_argument("--repo", type=str, default="ByteDance/SDXL-Lightning")
parser.add_argument("--cpkt", type=str, default="sdxl_lightning_2step_unet.safetensors")
parser.add_argument("--variant", type=str, default="fp16")
parser.add_argument(
    "--prompt",
    type=str,
    # default="street style, detailed, raw photo, woman, face, shot on CineStill 800T",
    default="A girl smiling",
)
parser.add_argument("--save_graph", action="store_true")
parser.add_argument("--load_graph", action="store_true")
parser.add_argument("--save_graph_dir", type=str, default="cached_pipe")
parser.add_argument("--load_graph_dir", type=str, default="cached_pipe")
parser.add_argument("--height", type=int, default=1024)
parser.add_argument("--width", type=int, default=1024)
parser.add_argument(
    "--saved_image", type=str, required=False, default="sdxl-light-out.png"
)
parser.add_argument("--seed", type=int, default=1)
parser.add_argument(
    "--compile",
    type=(lambda x: str(x).lower() in ["true", "1", "yes"]),
    default=True,
)
args = parser.parse_args()

import logging

import logging

logger = logging.getLogger("onediff-benchmark")
logger.setLevel(logging.INFO)
formatter = logging.Formatter(
    "%(asctime)s - %(levelname)s - %(message)s", "%Y-%m-%d %H:%M:%S"
)
console_handler = logging.StreamHandler()
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
logger.info(args)

OUTPUT_TYPE = "pil"

n_steps = int(args.cpkt[len("sdxl_lightning_") : len("sdxl_lightning_") + 1])

is_lora_cpkt = "lora" in args.cpkt

from diffusers import EulerDiscreteScheduler

if is_lora_cpkt:
    pipe = StableDiffusionXLPipeline.from_pretrained(
        args.base, torch_dtype=torch.float16, variant="fp16"
    ).to("cuda")
    if os.path.isfile(os.path.join(args.repo, args.cpkt)):
        pipe.load_lora_weights(os.path.join(args.repo, args.cpkt))
    else:
        pipe.load_lora_weights(hf_hub_download(args.repo, args.cpkt))
    pipe.fuse_lora()
else:
    from diffusers import UNet2DConditionModel

    unet = UNet2DConditionModel.from_config(args.base, subfolder="unet").to(
        "cuda", torch.float16
    )
    if os.path.isfile(os.path.join(args.repo, args.cpkt)):
        unet.load_state_dict(
            load_file(os.path.join(args.repo, args.cpkt), device="cuda")
        )
    else:
        unet.load_state_dict(
            load_file(hf_hub_download(args.repo, args.cpkt), device="cuda")
        )
    pipe = StableDiffusionXLPipeline.from_pretrained(
        args.base, unet=unet, torch_dtype=torch.float16, variant="fp16"
    ).to("cuda")

pipe.scheduler = EulerDiscreteScheduler.from_config(
    pipe.scheduler.config, timestep_spacing="trailing"
)

if pipe.vae.dtype == torch.float16 and pipe.vae.config.force_upcast:
    pipe.upcast_vae()

# Compile the pipeline
if args.compile:
    pipe = compile_pipe(
        pipe,
    )
    if args.load_graph:
        logger.info("Loading graphs...")
        load_pipe(pipe, args.load_graph_dir)
        logger.info(f"Graphs loaded from {args.load_graph_dir}")

logger.info("Warmup with running graphs...")
torch.manual_seed(args.seed)
image = pipe(
    prompt=args.prompt,
    height=args.height,
    width=args.width,
    num_inference_steps=n_steps,
    guidance_scale=0,
    output_type=OUTPUT_TYPE,
).images


if args.save_graph:
    logger.info("Saving graphs...")
    save_pipe(pipe, args.save_graph_dir)
    logger.info(f"Graphs saved to {args.save_graph_dir}")
