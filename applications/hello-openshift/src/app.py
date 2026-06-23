import os
from flask import Flask, render_template

app = Flask(__name__)


@app.route("/")
def index():
    return render_template(
        "index.html",
        pod_name=os.environ.get("POD_NAME", "unknown"),
        namespace=os.environ.get("POD_NAMESPACE", "unknown"),
        node_name=os.environ.get("NODE_NAME", "unknown"),
        pod_ip=os.environ.get("POD_IP", "unknown"),
    )


@app.route("/healthz")
def healthz():
    return "ok", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
