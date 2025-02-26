from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello_world() -> str:
    return "<p>Hello from python-teste!</p>"


def main() -> None:
    app.run()


if __name__ == "__main__":
    main()
