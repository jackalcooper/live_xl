#!/usr/bin/env python
import json, os

vd = (
    os.environ["CUDA_VISIBLE_DEVICES"] if "CUDA_VISIBLE_DEVICES" in os.environ else None
)


def log_with_prefix(msg):
    print(f"[gpu={vd}] {msg}")


log_with_prefix("starting")

import time
from time import sleep
import platform
import shutil
import traceback

if platform.system() == "Linux" and shutil.which("nvidia-smi") != None:
    try:
        import lightning
        import torch
    except Exception:
        print("Failed to initialize lightning or torch.")
        full_traceback = traceback.format_exc()
        print(full_traceback)
else:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--mock_sleep_seconds", type=int, default=1, required=False)
    args, unknown_args = parser.parse_known_args()
    unknown_args = " ".join(unknown_args)
    sleep_seconds = args.mock_sleep_seconds
    print(
        f"Simulate timeout by sleeping {sleep_seconds} seconds, ignoring args: {unknown_args}"
    )
    sleep(sleep_seconds)


def send_jsonl(obj, stream):
    """Write a JSON object to an output stream, followed by a newline."""
    json_data = json.dumps(obj)
    stream.write(json_data + "\n")
    try:
        stream.flush()
    except BrokenPipeError as _e:
        log_with_prefix(f"fail to write json {json_data[:300]}")


def recv_jsonl(stream):
    try:
        line = stream.readline()
        if not line:
            return None  # EOF or empty line
        return json.loads(line)
    except Exception:
        full_traceback = traceback.format_exc()
        return {"error": full_traceback}


def recv_loop_jsonl(stream):
    """Yield JSON objects from an input stream."""
    obj = recv_jsonl(stream)
    while obj is not None:
        yield obj
        obj = recv_jsonl(stream)


if __name__ == "__main__":
    # Assuming file descriptors 3 and 4 are opened for reading and writing respectively
    input, output = os.fdopen(3, "r", encoding="utf-8"), os.fdopen(
        4, "w", encoding="utf-8"
    )
    for message in recv_loop_jsonl(input):
        if "action" in message and message["action"] == "echo":
            send_jsonl(
                {
                    "action": "reply",
                    "ref": message["ref"] if "ref" in message else "undefined",
                    "payload": (
                        message["payload"] if "payload" in message else "nothing"
                    ),
                },
                output,
            )  # echo the message back
        elif "action" in message and message["action"] == "sleep":
            t = 0.3
            sleep(t)
            send_jsonl(
                {
                    "action": "reply",
                    "ref": message["ref"] if "ref" in message else "undefined",
                    "payload": {"time_millisecond": int(1000 * t)},
                },
                output,
            )  # echo the message back
        elif (
            "action" in message
            and message["action"] == "infer_lightning"
            and "payload" in message
        ):
            try:
                args = message["payload"]["args"]
                seed = args.pop("seed", 1)
                args["generator"] = torch.Generator(device="cuda").manual_seed(seed)
                start_time = time.time()
                images = lightning.pipe(**args).images
                end_time = time.time()
                images[0].save(args["saved_image"])
            except Exception:
                full_traceback = traceback.format_exc()
                send_jsonl(
                    {
                        "action": "reply",
                        "ref": message["ref"] if "ref" in message else "undefined",
                        "error": full_traceback,
                    },
                    output,
                )
            else:
                send_jsonl(
                    {
                        "action": "reply",
                        "ref": message["ref"] if "ref" in message else "undefined",
                        "payload": "success",
                        "inference_time": end_time - start_time,
                    },
                    output,
                )
        elif "error" in message:
            send_jsonl(
                {
                    "action": "reply",
                    "ref": message["ref"] if "ref" in message else "undefined",
                    "error": message["error"],
                },
                output,
            )
        else:
            send_jsonl(
                {
                    "action": "reply",
                    "ref": message["ref"] if "ref" in message else "undefined",
                    "error": (
                        f"action '{message['action']}' not supported"
                        if "action" in message
                        else "action not defined"
                    ),
                },
                output,
            )

    log_with_prefix("normal exit")
