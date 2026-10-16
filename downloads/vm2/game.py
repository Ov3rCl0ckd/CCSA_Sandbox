
import http.server
import socketserver
import time

PORT = 80
HOST = "10.2.0.4"

HTML_CONTENT = """
<!DOCTYPE html>
<html>
<head>
    <title>CCSA Target Server: SNAKE</title>
    <style>
        * { box-sizing: border-box; }
        body {
            background: #111;
            color: #0f0;
            text-align: center;
            font-family: monospace;
            margin: 0;
            padding: 20px;
        }
        h1 { font-size: 22px; margin-bottom: 4px; }
        p  { color: #888; font-size: 13px; margin: 4px 0 12px; }
        #gameWrapper { position: relative; display: inline-block; }
        canvas {
            background: #000;
            border: 4px solid #0f0;
            box-shadow: 0 0 24px #0f0;
            display: block;
        }
        #attackOverlay {
            display: none;
            position: absolute;
            top: 0; left: 0;
            width: 400px; height: 400px;
            background: rgba(180, 0, 0, 0.88);
            border: 4px solid red;
            box-shadow: 0 0 40px red;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            color: #fff;
        }
        #attackOverlay.show { display: flex; }
        #attackOverlay h2 {
            font-size: 30px;
            color: #ff4444;
            text-shadow: 0 0 12px red;
            margin: 0 0 10px;
            letter-spacing: 2px;
        }
        #attackOverlay .sub {
            font-size: 15px;
            color: #ffaaaa;
            margin: 4px 0;
        }
        #attackOverlay .blink {
            font-size: 13px;
            color: #ff8888;
            margin-top: 18px;
            animation: blink 1s step-end infinite;
        }
        @keyframes blink { 50% { opacity: 0; } }
        #scoreBoard {
            display: flex;
            justify-content: space-between;
            width: 400px;
            margin: 8px auto 4px;
            font-size: 15px;
        }
        #status {
            font-size: 20px;
            font-weight: bold;
            margin-top: 14px;
        }
        #status.offline { color: red; text-shadow: 0 0 10px red; }
    </style>
</head>
<body>
    <h1>CCSA Vulnerable Server: Operation SYN Flood</h1>
    <p>Use Arrow Keys to play Snake. Watch what happens when the attack hits.</p>

    <div id="scoreBoard">
        <span>Score: <span id="scoreVal">0</span></span>
        <span>High Score: <span id="highVal">0</span></span>
        <span>Level: <span id="levelVal">1</span></span>
    </div>

    <div id="gameWrapper">
        <canvas id="gameCanvas" width="400" height="400"></canvas>
        <div id="attackOverlay">
            <h2>!! GAME OVER !!</h2>
            <div class="sub">SERVER UNDER ATTACK</div>
            <div class="sub">SYN FLOOD DETECTED</div>
            <div class="sub" style="margin-top:10px;font-size:13px;color:#ffcccc;">
                Connection to game server lost...
            </div>
            <div class="blink">Waiting for server to recover...</div>
        </div>
    </div>

    <div id="status">Server Status: ONLINE</div>

    <script>
    (() => {
        const canvas = document.getElementById("gameCanvas");
        const ctx    = canvas.getContext("2d");
        const GRID   = 20;
        const COLS   = canvas.width  / GRID;
        const ROWS   = canvas.height / GRID;

        let snake, food, dx, dy, score, highScore, level, gameLoopId;
        let gameOver    = false;
        let underAttack = false;
        highScore = 0;

        function randomFoodPos(body) {
            let pos;
            do {
                pos = {
                    x: Math.floor(Math.random() * COLS) * GRID,
                    y: Math.floor(Math.random() * ROWS) * GRID
                };
            } while (body.some(s => s.x === pos.x && s.y === pos.y));
            return pos;
        }

        function resetGame() {
            snake    = [{x:200,y:200},{x:180,y:200},{x:160,y:200}];
            food     = randomFoodPos(snake);
            dx       = GRID; dy = 0;
            score    = 0; level = 1;
            gameOver = false;
            updateBoard();
        }

        function updateBoard() {
            document.getElementById("scoreVal").textContent = score;
            document.getElementById("highVal").textContent  = highScore;
            document.getElementById("levelVal").textContent = level;
        }

        function draw() {
            // Fill black explicitly so canvas never shows white
            ctx.fillStyle = "#000";
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Subtle grid dots
            ctx.fillStyle = "#1a1a1a";
            for (let x = 0; x < canvas.width; x += GRID)
                for (let y = 0; y < canvas.height; y += GRID)
                    ctx.fillRect(x + 9, y + 9, 2, 2);

            // Food
            ctx.shadowBlur  = 12;
            ctx.shadowColor = "red";
            ctx.fillStyle   = "#ff3333";
            ctx.fillRect(food.x + 2, food.y + 2, GRID - 4, GRID - 4);
            ctx.shadowBlur  = 0;

            // Snake
            snake.forEach((part, i) => {
                if (i === 0) {
                    ctx.shadowBlur  = 10;
                    ctx.shadowColor = "#00ff00";
                    ctx.fillStyle   = "#00ff00";
                } else {
                    ctx.shadowBlur = 0;
                    const g = Math.floor(200 - (i / snake.length) * 120);
                    ctx.fillStyle = `rgb(0,${g},0)`;
                }
                ctx.fillRect(part.x + 1, part.y + 1, GRID - 2, GRID - 2);
            });
            ctx.shadowBlur = 0;

            // Self-collision game over screen
            if (gameOver) {
                ctx.fillStyle = "rgba(0,0,0,0.75)";
                ctx.fillRect(0, 0, canvas.width, canvas.height);
                ctx.fillStyle = "#0f0";
                ctx.font      = "bold 28px monospace";
                ctx.textAlign = "center";
                ctx.fillText("GAME OVER", canvas.width / 2, 170);
                ctx.font      = "16px monospace";
                ctx.fillStyle = "#888";
                ctx.fillText("Score: " + score, canvas.width / 2, 210);
                ctx.fillStyle = "#0f0";
                ctx.fillText("Press SPACE to restart", canvas.width / 2, 250);
            }
        }

        function getSpeed() {
            return Math.max(60, 150 - (level - 1) * 10);
        }

        function tick() {
            if (gameOver || underAttack) return;

            const head = { x: snake[0].x + dx, y: snake[0].y + dy };

            if (head.x < 0)             head.x = (COLS - 1) * GRID;
            if (head.x >= canvas.width) head.x = 0;
            if (head.y < 0)             head.y = (ROWS - 1) * GRID;
            if (head.y >= canvas.height) head.y = 0;

            if (snake.some(s => s.x === head.x && s.y === head.y)) {
                gameOver = true;
                if (score > highScore) highScore = score;
                updateBoard();
                draw();
                return;
            }

            snake.unshift(head);

            if (head.x === food.x && head.y === food.y) {
                score++;
                if (score > highScore) highScore = score;
                level = Math.floor(score / 5) + 1;
                food  = randomFoodPos(snake);
                updateBoard();
            } else {
                snake.pop();
            }

            draw();
            gameLoopId = setTimeout(tick, getSpeed());
        }

        function startLoop() {
            clearTimeout(gameLoopId);
            gameLoopId = setTimeout(tick, getSpeed());
        }

        document.addEventListener("keydown", e => {
            if (e.key === " " && gameOver && !underAttack) {
                resetGame(); startLoop(); return;
            }
            if (e.key === "ArrowUp"    && dy === 0)  { dx =  0;    dy = -GRID; }
            if (e.key === "ArrowDown"  && dy === 0)  { dx =  0;    dy =  GRID; }
            if (e.key === "ArrowLeft"  && dx === 0)  { dx = -GRID; dy =  0;    }
            if (e.key === "ArrowRight" && dx === 0)  { dx =  GRID; dy =  0;    }
        });

        const overlay   = document.getElementById("attackOverlay");
        const statusDiv = document.getElementById("status");

        function setAttack() {
            if (underAttack) return;
            underAttack = true;
            clearTimeout(gameLoopId);
            overlay.classList.add("show");
            statusDiv.textContent = "Server Status: OFFLINE (SYN FLOOD DETECTED)";
            statusDiv.classList.add("offline");
        }

        function setOnline() {
            if (!underAttack) return;   // already online: do NOT reset the game
            underAttack = false;
            successStreak = 0;
            overlay.classList.remove("show");
            statusDiv.textContent = "Server Status: ONLINE";
            statusDiv.classList.remove("offline");
            resetGame();
            startLoop();
        }

        // Heartbeat — 1s hard timeout, requires 5 consecutive successes
        // before declaring recovery to prevent brief server blips from
        // clearing the attack state prematurely
        let successStreak = 0;
        const RECOVERY_THRESHOLD = 5;

        setInterval(() => {
            fetch("/ping", {
                cache:  "no-store",
                method: "GET",
                signal: AbortSignal.timeout(1000)
            })
            .then(res => {
                if (res.ok) {
                    // Only attempt recovery while we are actually down.
                    // Otherwise a healthy server resets the game every cycle.
                    if (underAttack) {
                        successStreak++;
                        if (successStreak >= RECOVERY_THRESHOLD) setOnline();
                    }
                } else {
                    successStreak = 0;
                    setAttack();
                }
            })
            .catch(() => {
                successStreak = 0;
                setAttack();
            });
        }, 1500);

        resetGame();
        startLoop();
    })();
    </script>
</body>
</html>
"""


class FragileGameHandler(http.server.BaseHTTPRequestHandler):
    RESPONSE_DELAY = 0.2  # seconds — MUST stay below the page's 1s heartbeat
                          # timeout, otherwise an idle server looks "under attack"

    def do_GET(self):
        time.sleep(self.RESPONSE_DELAY)
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()
        if self.path == "/ping":
            self.wfile.write(b"pong")
        else:
            self.wfile.write(HTML_CONTENT.encode("utf-8"))

    def log_message(self, format, *args):
        pass


class CustomTCPServer(socketserver.TCPServer):
    allow_reuse_address = True
    request_queue_size  = 1


def print_banner():
    print("=" * 60)
    print("  CCSA Fragile Snake Game Server")
    print("=" * 60)
    print()
    print("  REQUIRED OS SETUP (run on this Kali VM first):")
    print()
    print("    sudo sysctl -w net.ipv4.tcp_syncookies=0")
    print("    sudo sysctl -w net.ipv4.tcp_max_syn_backlog=128")
    print()
    print("  ATTACK COMMAND (from attacker machine):")
    print()
    print("    sudo hping3 -S --flood -V -p 80 10.2.0.4")
    print()
    print("=" * 60)
    print(f"  Server listening on {HOST}:{PORT}")
    print("=" * 60)
    print()


with CustomTCPServer((HOST, PORT), FragileGameHandler) as httpd:
    print_banner()
    httpd.serve_forever()
