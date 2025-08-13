# sudo apt install python3-flask
from flask import Flask, render_template_string, request
import sys

app = Flask(__name__)
PORT = "/dev/ttyACM0"
BAUD = 9600

# Mock serial.Serial if not running on the real device
try:
    import serial
    ser = serial.Serial(PORT, BAUD, timeout=1)
except Exception:
    class DummySerial:
        def write(self, data):
            print(f"Mock write: {data.decode().strip()}", file=sys.stderr)
    ser = DummySerial()

html = """
<!DOCTYPE html>
<html>
<head>
  <title>Ovládání Relé</title>
  <style>
    body {
      background: #f7f7f7;
      font-family: Arial, sans-serif;
      text-align: center;
      margin: 0;
      padding: 0;
    }
    h1 {
      background: #2d7cff;
      color: white;
      padding: 30px 0 20px 0;
      margin-bottom: 30px;
      box-shadow: 0 2px 8px #aaa;
    }
    h3 {
      color: #2d7cff;
      margin-top: 30px;
    }
    form {
      display: inline-block;
      margin-bottom: 20px;
    }
    button {
      padding: 10px 30px;
      margin: 10px;
      font-size: 20px;
      border: none;
      border-radius: 8px;
      background: #2d7cff;
      color: white;
      cursor: pointer;
      transition: background 0.2s;
      box-shadow: 0 2px 6px #bbb;
    }
    button:hover {
      background: #1a4fa3;
    }
  </style>
</head>
<body>
  <h1>Ovládání relé</h1>
  {% for r in [1,2,3] %}
    <h3>Relé {{ r }}</h3>
    <form method="post">
      <button name="cmd" value="R{{ r }}:1">Zapnout</button>
      <button name="cmd" value="R{{ r }}:0">Vypnout</button>
    </form>
  {% endfor %}
</body>
</html>
"""

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        cmd = request.form["cmd"]
        ser.write((cmd + "\n").encode())
        # Print relay action to terminal
        relay, state = cmd.split(":")
        action = "ON" if state == "1" else "OFF"
        print(f"Relay {relay[-1]} turned {action}", file=sys.stderr)
    return render_template_string(html)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)