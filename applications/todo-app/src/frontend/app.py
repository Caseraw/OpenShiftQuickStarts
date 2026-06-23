import os

import psycopg2
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)


def get_db_connection_params():
    """Resolve PostgreSQL connection settings from the environment.

    Prefer DATABASE_URL when set. Otherwise use DB_HOST and related variables
    so the target can be any resolvable hostname, including OpenShift Service
    DNS on the same cluster or a cross-cluster service name on a shared network.
    """
    database_url = os.environ.get("DATABASE_URL", "").strip()
    if database_url:
        return {"dsn": database_url}

    required = ("DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD")
    missing = [name for name in required if not os.environ.get(name, "").strip()]
    if missing:
        raise RuntimeError(
            "Database not configured: set DATABASE_URL or "
            + ", ".join(missing)
        )

    params = {
        "host": os.environ["DB_HOST"].strip(),
        "port": os.environ.get("DB_PORT", "5432").strip(),
        "dbname": os.environ["DB_NAME"].strip(),
        "user": os.environ["DB_USER"].strip(),
        "password": os.environ["DB_PASSWORD"],
    }

    sslmode = os.environ.get("DB_SSLMODE", "").strip()
    if sslmode:
        params["sslmode"] = sslmode

    connect_timeout = os.environ.get("DB_CONNECT_TIMEOUT", "").strip()
    if connect_timeout:
        params["connect_timeout"] = int(connect_timeout)

    return params


def get_db_connection():
    params = get_db_connection_params()
    if "dsn" in params:
        return psycopg2.connect(params["dsn"])
    return psycopg2.connect(**params)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/ready")
def ready():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return jsonify(status="ok", database="connected")
    except Exception as exc:
        return jsonify(status="error", database=str(exc)), 503


@app.route("/api/todos", methods=["GET"])
def list_todos():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, title, done FROM todos ORDER BY id"
            )
            rows = cur.fetchall()
    return jsonify([{"id": r[0], "title": r[1], "done": r[2]} for r in rows])


@app.route("/api/todos", methods=["POST"])
def create_todo():
    data = request.get_json(force=True)
    title = (data.get("title") or "").strip()
    if not title:
        return jsonify(error="title is required"), 400

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO todos (title) VALUES (%s) RETURNING id, title, done",
                (title,),
            )
            row = cur.fetchone()
        conn.commit()
    return jsonify({"id": row[0], "title": row[1], "done": row[2]}), 201


@app.route("/api/todos/<int:todo_id>", methods=["PUT"])
def update_todo(todo_id):
    data = request.get_json(force=True)
    title = data.get("title")
    done = data.get("done")

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            if title is not None and done is not None:
                cur.execute(
                    "UPDATE todos SET title = %s, done = %s WHERE id = %s "
                    "RETURNING id, title, done",
                    (title.strip(), bool(done), todo_id),
                )
            elif done is not None:
                cur.execute(
                    "UPDATE todos SET done = %s WHERE id = %s "
                    "RETURNING id, title, done",
                    (bool(done), todo_id),
                )
            elif title is not None:
                cur.execute(
                    "UPDATE todos SET title = %s WHERE id = %s "
                    "RETURNING id, title, done",
                    (title.strip(), todo_id),
                )
            else:
                return jsonify(error="nothing to update"), 400
            row = cur.fetchone()
        conn.commit()

    if row is None:
        return jsonify(error="not found"), 404
    return jsonify({"id": row[0], "title": row[1], "done": row[2]})


@app.route("/api/todos/<int:todo_id>", methods=["DELETE"])
def delete_todo(todo_id):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM todos WHERE id = %s RETURNING id", (todo_id,))
            row = cur.fetchone()
        conn.commit()

    if row is None:
        return jsonify(error="not found"), 404
    return "", 204
