import os
import time
from uuid import uuid4

import modal
import requests


SGL_LOG_LEVEL = "error"  # try "debug" or "info" if you have issues

MINUTES = 60  # seconds

MODEL_PATH = "meta-llama/Meta-llama-3-70b-Instruct"
MODEL_CHAT_TEMPLATE = "llama-3-instruct"


def download_model_to_image():
    import transformers
    from huggingface_hub import snapshot_download
    snapshot_download(
        MODEL_PATH,
        ignore_patterns=["*.pt", "*.bin"],
    )

    # otherwise, this happens on first inference
    transformers.utils.move_cache()

sglang_image = (
    modal.Image.from_registry(  # start from an official NVIDIA CUDA image
        "nvidia/cuda:12.2.0-devel-ubuntu22.04", add_python="3.11"
    )
    .apt_install("git")  # add system dependencies
    .pip_install(  # add sglang and some Python dependencies
        "sglang[srt]==0.1.16",
        "ninja",
        "packaging",
        "transformers==4.40.2",
    )
    .run_function(  # download the model by running a Python function
        download_model_to_image
    )
)


class Colors:
    """ANSI color codes"""

    GREEN = "\033[0;32m"
    BLUE = "\033[0;34m"
    GRAY = "\033[0;90m"
    BOLD = "\033[1m"
    END = "\033[0m"

###############################################################################
SYSTEM_PROMPT = """You are an expert maze builder.

A maze is described by a grid of cells, where cells are either walls, passageways, or rooms.
Rooms are said to be connected if they are both adjacent to the same passage, and rooms must be connected to other rooms, up to a limit of 4.

Mazes are represented using 2d arrays, which we will implement with nested lists. Here is an example of a 3x3 maze.
[['x','x','x','x','x','x','x']
,['x','r','p','r','p','r','x']
,['x','x','x','x','x','p','x']
,['x','r','p','r','p','r','x']
,['x','p','x','p','x','x','x']
,['x','r','x','r','p','r','p']
,['x','x','x','x','x','x','x']
]
"""
MAZE_REGEX = (
    r"\[\[('r','[px]',){3}'r'\],\n"
    +r"\[('[px]','x',){3}'x'\],\n"
    +r"\[('r','[px]',){3}'r'\],\n"
    +r"\[('[px]','x',){3}'x'\],\n"
    +r"\[('r','[px]',){3}'r'\],\n"
    +r"\[('[px]','x',){3}'x'\],\n"
    +r"\[('r','[px]',){3}'r'\],\n"
    +r"\]"
)

app = modal.App("app")
@app.cls(
    gpu=modal.gpu.A100(size="80GB",count=8),
    timeout=20 * MINUTES,
    container_idle_timeout=20 * MINUTES,
    allow_concurrent_inputs=100,
    image=sglang_image,
)

class Model:
    @modal.enter()  # what should a container do after it starts but before it gets input?
    async def start_runtime(self):
        """Starts an SGL runtime to execute inference."""
        
        from huggingface_hub import login
        login(token=os.environ.get('HF_TOKEN'))

        import sglang as sgl
        self.runtime = sgl.Runtime(
            model_path=MODEL_PATH,
            tp_size=GPU_COUNT,  # t_ensor p_arralel size, number of GPUs to split the model over
            log_evel=SGL_LOG_LEVEL,
        )
        self.runtime.endpoint.chat_template = (
            sgl.lang.chat_template.get_chat_template(MODEL_CHAT_TEMPLATE)
        )
        sgl.set_default_backend(self.runtime)

    @modal.web_endpoint(method="POST")
    async def generate(self, query: str = None):
        import sglang as sgl

        start = time.monotonic_ns()
        request_id = uuid4()
        print(f"Generating response to request {request_id}")
        
        @sgl.function
        def run_mazegen(s, query):
            s += sgl.system(SYSTEM_PROMPT)
            s += sgl.user(query)
            s += sgl.assistant(sgl.gen("maze", regex=MAZE_REGEX))

        if query is None:
            query = """Generate a random 3x3 Maze. Don't write code. Just output the maze representation."""

        state = run_mazegen.run(
            query=query,
            temperature=0
        )
        # show the question and response in the terminal for demonstration purposes
        print(
            Colors.BOLD, Colors.GRAY, "Query: ", query, Colors.END, sep=""
        )
        maze = state["maze"]
        print(
            Colors.BOLD,
            Colors.GREEN,
            f"Maze: {maze}",
            Colors.END,
            sep="",
        )
        print(
            f"request {request_id} completed in {round((time.monotonic_ns() - start) / 1e9, 2)} seconds"
        )

    @modal.exit()  # what should a container do before it shuts down?
    def shutdown_runtime(self):
        self.runtime.shutdown()


@app.local_entrypoint()
def main(query=None):
    model = Model()

    response = requests.post(
        model.generate.web_url,
        json={"query": query},
    )
    assert response.ok, response.status_code
