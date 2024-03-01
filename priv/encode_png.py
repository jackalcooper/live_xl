import base64
import sys
import time

with open(sys.argv[1], "rb") as image_file:
    start_time = time.time()
    encoded_string = base64.b64encode(image_file.read()).decode("utf-8")
    end_time = time.time()
    print(f"Time taken to encode the image: {end_time - start_time} seconds")
