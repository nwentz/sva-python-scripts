"""Arcade Baseball: Player vs CPU.
Controls:
  TITLE: 1-5 or LEFT/RIGHT + SPACE to pick a mode and start, H for rules
  BATTING (you bat): mouse aims the cursor, SPACE starts the meter, SPACE again locks power and swings. UP=fly / DOWN=grounder.
  PITCHING (you pitch): Mouse to aim, SPACE to start/stop power meter, then pitch.
  BALL IN PLAY (defense): Arrow keys / WASD to move fielder (circled).
  P: pause, Q/Esc: quit to menu, F11/F: fullscreen, R / SPACE on game over to restart.
Run with: py -3.13 baseball_game.py
"""
import math
import random
import sys

import pygame

from game_config import (
    BLUE,
    BROWN,
    DIFF_LABEL,
    DIFF_PARAMS,
    DIFF_SUB,
    DIFFS,
    FPS,
    GREEN_D,
    GREEN_L,
    H,
    INNINGS,
    METER_GREEN,
    METER_RED,
    PRAC_LABEL,
    PRAC_SUB,
    PRACS,
    RED,
    STAND_BG,
    STRIKE_ZONE,
    BASE1,
    BASE2,
    BASE3,
    BLACK,
    HOME,
    MOUND,
    W,
    WHITE,
    WIN_H,
    WIN_W,
    YELLOW,
    px,
)


class _CachedFont:
    """Wraps a pygame font so identical text renders once, not every frame.

    Big 2K glyphs are expensive to rasterize; HUD/title/rules text is mostly
    static between frames. Transparent: every attribute except render()
    forwards to the real font, so all existing call sites work unchanged.
    """

    def __init__(self, font, cache, limit=512):
        object.__setattr__(self, "_font", font)
        object.__setattr__(self, "_cache", cache)
        object.__setattr__(self, "_limit", limit)

    def __getattr__(self, name):
        return getattr(object.__getattribute__(self, "_font"), name)

    def __setattr__(self, name, value):
        setattr(object.__getattribute__(self, "_font"), name, value)

    def render(self, txt, antialias, color, bgcolor=None):
        key = (id(object.__getattribute__(self, "_font")), txt, color, bgcolor)
        cache = object.__getattribute__(self, "_cache")
        s = cache.get(key)
        if s is None:
            if len(cache) > object.__getattribute__(self, "_limit"):
                cache.pop(next(iter(cache)))
            real = object.__getattribute__(self, "_font")
            if bgcolor is not None:
                s = real.render(txt, antialias, color, bgcolor)
            else:
                s = real.render(txt, antialias, color)
            cache[key] = s
        return s


class Game:

    def __init__(self):
        pygame.init()
        pygame.display.set_caption("Arcade Baseball - Player vs CPU")
        # Resizable decorated window (title bar with minimize/maximize/close
        # always stays). The game renders natively at 2K (1994x1440) and
        # present() scales it to whatever size the window is.
        self.display = pygame.display.set_mode((WIN_W, WIN_H), pygame.RESIZABLE)
        self.screen = pygame.Surface((W, H))
        self.clock = pygame.time.Clock()
        self.font = pygame.font.SysFont("arial", px(22), bold=True)
        self.big = pygame.font.SysFont("arial", px(44), bold=True)
        self.small = pygame.font.SysFont("arial", px(16))
        self.wall_font = pygame.font.SysFont("arial", px(13), bold=True)
        self.title_font = pygame.font.SysFont("arial", px(60), bold=True)
        self.rules_font = pygame.font.SysFont("arial", px(32), bold=True)
        self.difficulty = "easy"
        self.menu_index = 0
        self.fullscreen = False
        self.win = None
        self._gloves = {}  # (radius, raised) -> pre-rendered mitt sprite
        self._text = {}  # rendered-text cache shared by all fonts
        for _name in ("font", "big", "small", "wall_font", "title_font", "rules_font"):
            setattr(self, _name, _CachedFont(getattr(self, _name), self._text))
        dim = pygame.Surface((W, H), pygame.SRCALPHA)
        dim.fill((0, 0, 0, 140))
        self._pause_dim = dim
        self.reset()

    def viewport(self):
        # scale + offset mapping the 2K canvas onto the current window
        ww, wh = self.display.get_size()
        s = max(min(ww / W, wh / H), 1e-6)  # never divide by zero
        sw, sh = max(1, int(W * s)), max(1, int(H * s))
        return s, (ww - sw) // 2, (wh - sh) // 2, sw, sh

    def apply_display(self):
        # Maximized window fills the screen while keeping the OS title bar
        # (minimize / maximize / close), unlike exclusive fullscreen.
        try:
            if self.win is None:
                from pygame._sdl2.video import Window
                self.win = Window.from_display_module()
            if self.fullscreen:
                self.win.maximize()
            else:
                self.win.restore()
        except pygame.error:
            self.fullscreen = False
            self.say("Maximized window not available on this display.")

    def toggle_fullscreen(self):
        self.fullscreen = not self.fullscreen
        self.apply_display()

    def to_logical(self, pos):
        # map a real window (mouse) position back to 2K game coords
        s, ox, oy, _, _ = self.viewport()
        x, y = pos
        return ((x - ox) / s, (y - oy) / s)

    def present(self):
        ww, wh = self.display.get_size()
        if abs(ww - W) <= 2 and abs(wh - H) <= 2:
            # effectively 1:1 (e.g. 1440p maximized) — direct blit,
            # skipping a full-canvas resample every frame
            self.display.fill((0, 0, 0))
            self.display.blit(self.screen, ((ww - W) // 2, (wh - H) // 2))
        else:
            # native 2K canvas, smoothscale only bridges window-size mismatch
            s, ox, oy, sw, sh = self.viewport()
            self.display.fill((0, 0, 0))
            self.display.blit(pygame.transform.smoothscale(self.screen, (sw, sh)), (ox, oy))
        pygame.display.flip()

    def diff(self):
        return DIFF_PARAMS[self.difficulty]

    def diff_name(self):
        return DIFF_LABEL[self.difficulty]

    def max_innings(self):
        return DIFF_PARAMS[self.difficulty].get("innings", INNINGS)

    def reset(self):
        self.score = [0, 0]  # [CPU, Player]
        self.inning = 1
        # Player bat first: start Bottom 1, then Top 1, Bottom 2, Top 2, ...
        self.top = False  # False = Player bat / CPU pitches, True = CPU bats / you pitch
        self.outs = 0
        self.balls = 0
        self.strikes = 0
        self.bases = [False, False, False]
        self.state = "title"
        self.msg = "Press SPACE to play!"
        self.sub = "Player bats first! Pick a mode."
        self.paused = False
        self.practice = None  # None | "bat" | "pitch"
        # pitch anim
        self.pitch = None
        self.swing_done = False
        self.aim = [W // 2, H - px(170)]
        self.meter = 0.0
        self.meter_dir = 1
        self.meter_active = False
        self.meter_value = 0.5
        self.ball_play = None
        self.fielders = self.default_field_positions()
        self.player_fielder = 6
        self.windup_t = 0
        self.pitch_coming = False
        self.cpu_pitch = None
        self.bat_power = 0.0
        self.bat_charging = False
        self.bat_dir = 1
        self.bat_anim = 0.0  # >0 while the bat swings through the zone
        self.bat_aim = [W // 2, STRIKE_ZONE.centery]  # batting cursor: where you aim
        self.pending_hit = None  # (offense, quality) waiting out the contact beat
        self.contact_t = 0.0
        # runner animation (show characters advancing / scoring)
        self.runners_anim = []
        self.runners_t = 0.0
        self.runners_dur = 1.8
        # stadium crowd (fixed seats so they don't flicker; jittered grid
        # with 24px cells so dots never intersect each other)
        rng = random.Random(12345)
        palette = [(255, 220, 180), (240, 180, 140), (200, 150, 110),
                   (220, 60, 60), (60, 120, 220), (250, 210, 80),
                   (90, 200, 120), (200, 200, 200), (150, 90, 200)]
        cells = [(px(8) + cx * px(11), px(72) + cy * px(11))
                 for cy in range(7) for cx in range(81)]
        rng.shuffle(cells)
        self.crowd = [(x + px(11) // 2 + rng.randint(-px(1), px(1)),
                       y + px(11) // 2 + rng.randint(-px(1), px(1)),
                       rng.choice(palette)) for (x, y) in cells[:380]]
        # HR celebration: left half (x < W/2) = Player fans, right half = CPU fans
        self.crowd_celebrate = None  # None | "you" | "cpu"
        self.crowd_big = False  # big HR celebration vs small run-scoring one
        self.crowd_timer = 0.0
        self.hr_flash = 0.0  # agent experiment: full-screen HR flash overlay
        self.hr_banner = ""
        self.build_static_bg()

    # ---------- helpers ----------
    def say(self, msg, sub=""):
        self.msg = msg
        self.sub = sub

    def batting_team(self):
        return "CPU" if self.top else "Player"

    def new_batter(self):
        self.balls = 0
        self.strikes = 0
        self.pitch = None
        self.swing_done = False
        self.pitch_coming = False
        self.cpu_pitch = None
        self.ball_play = None
        self.bat_power = 0.0
        self.bat_charging = False
        self.bat_dir = 1
        self.bat_anim = 0.0
        self.bat_aim = [W // 2, STRIKE_ZONE.centery]
        self.meter_active = False
        self.fielders = self.default_field_positions()
        self.player_fielder = 6

    def end_half_inning(self):
        self.bases = [False, False, False]
        self.outs = 0
        # bottom-first order: Bottom -> Top (same inning), Top -> Bottom (next inning)
        if not self.top:
            self.top = True
        else:
            self.top = False
            self.inning += 1
        self.new_batter()
        total = self.max_innings()
        if self.inning > total:
            # tie -> extra inning
            if self.score[0] == self.score[1]:
                self.inning = total + 1  # show as extra, keep playing
                self.say(f"TIE! Extra inning!", "CPU %d - Player %d" % tuple(self.score))
            else:
                self.state = "gameover"
                return
        half = "Top" if self.top else "Bottom"
        self.say(f"Inning {min(self.inning, total)} - {half} ({self.batting_team()} bats)",
                 "Player pitches!" if self.top else "Player bats! SPACE x2 to swing")
        self.state = "pitch" if self.top else "batwait"
        if self.state == "pitch":
            self.meter_active = False
        if self.state == "batwait":
            self.start_cpu_pitch()

    def add_out(self):
        self.outs += 1
        if self.outs >= 3:
            if self.practice:
                # endless practice: fresh round, same side, no game over
                self.outs = 0
                self.bases = [False, False, False]
                self.say("Fresh round — practice continues!", "Q: menu when done.")
                self.new_batter()
                self.state = "pitch" if self.top else "batwait"
                if self.state == "batwait":
                    self.start_cpu_pitch()
                return
            self.say("Side retired!")
            self.end_half_inning()
        else:
            self.new_batter()
            self.state = "pitch" if self.top else "batwait"
            if self.state == "batwait":
                self.start_cpu_pitch()

    def base_point(self, i):
        # 0 = home (batter start), 1 = 1B, 2 = 2B, 3 = 3B, 4 = home (scored)
        if i <= 0 or i >= 4:
            return (HOME[0], HOME[1] - px(20))
        return (BASE1, BASE2, BASE3)[i - 1]

    def default_field_positions(self):
        # P, 1B, 2B, SS, 3B, LF, CF, RF — standard layout like the positions
        # diagram: P center, 1B/3B at their bags, 2B/SS up the middle
        # (2B right, SS left), LF/CF/RF spread across the outfield below the wall.
        # CF shades slightly right of straightaway so its ring never merges
        # with the 2B bag and diamond corner.
        return [
            [MOUND[0], MOUND[1]],
            [BASE1[0] + px(28), BASE1[1] - px(10)],
            [W // 2 + px(85), H - px(398)],
            [W // 2 - px(85), H - px(398)],
            [BASE3[0] - px(28), BASE3[1] - px(10)],
            [W // 2 - px(200), px(225)],
            [W // 2 + px(24), px(192)],
            [W // 2 + px(200), px(225)],
        ]

    def runner_path(self, start, end):
        # waypoints along the diamond from start base to end base
        pts = [self.base_point(i) for i in range(start, end + 1)]
        return pts

    def start_runner_sequence(self, moves, main_msg, sub_msg="", dur=1.8, batter_start=None):
        """moves: list of (start_base, end_base). 0=home/batter, 4=home/scored.
        batter_start: where the sprint ended mid-flight — the batter's run
        continues from there instead of teleporting back home."""
        self.runners_anim = []
        for idx, (s, e) in enumerate(moves):
            if e <= s:
                continue
            if s == 0 and batter_start is not None:
                path = [batter_start] + self.runner_path(s, e)[1:]
            elif s >= 1:
                # holders start from their lead, not the bag itself
                path = [self.base_lead(s - 1)] + self.runner_path(s, e)[1:]
            else:
                path = self.runner_path(s, e)
            if e in (1, 2, 3):
                # touch the bag, then step out to the lead: matches exactly
                # where the stationary dot draws, so there is no snap
                path = path + [self.base_lead(e - 1)]
            if e == 4:
                # scorers cross the plate, then spread to their own spots so
                # a multi-run trot never stacks: 3rd-runner front-right of
                # the batter, others fanned out
                dx, dy = {0: (-px(14), -px(5)), 1: (px(41), -px(23)),
                          2: (-px(41), px(18)), 3: (px(32), px(25))}[s]
                path = path + [(HOME[0] + dx, HOME[1] + dy)]
            # drop zero-length legs (e.g. batter already standing on the bag):
            # the hop arc on them reads as hovering in place
            clean = [path[0]]
            for pt in path[1:]:
                if math.hypot(pt[0] - clean[-1][0], pt[1] - clean[-1][1]) > 2:
                    clean.append(pt)
            path = clean
            self.runners_anim.append({
                "path": path,
                "delay": idx * 0.15,
                "scored": e == 4,
                "offense_cpu": self.top,
            })
        self.runners_t = 0.0
        self.runners_dur = dur
        self.say(main_msg, sub_msg)
        self.state = "runners"

    def update_runners(self, dt):
        self.runners_t += dt
        self.separate_fielders()
        # allow skip with SPACE handled in event loop; auto-advance when done
        if self.runners_t >= self.runners_dur + len(self.runners_anim) * 0.15 + 0.3:
            self.runners_anim = []
            self.after_at_bat()

    def runner_pos(self, anim):
        # position along path given global time (eased: sprint out, settle in)
        local = (self.runners_t - anim["delay"]) / max(0.01, self.runners_dur)
        local = max(0.0, min(1.0, local))
        local = local * local * (3 - 2 * local)
        path = anim["path"]
        if len(path) < 2:
            return path[0]
        segs = len(path) - 1
        f = local * segs
        si = min(segs - 1, int(f))
        frac = f - si
        x0, y0 = path[si]
        x1, y1 = path[si + 1]
        return (x0 + (x1 - x0) * frac, y0 + (y1 - y0) * frac - math.sin(frac * math.pi) * px(6))

    def base_lead(self, i):
        # where the runner on base i stands: a clear lead off the bag so
        # the dot and ring never touch the base square
        rx, ry = self.base_point(i + 1)
        ox, oy = ((-px(22), px(15)), (-px(32), px(14)), (px(22), px(15)))[i]
        return (rx + ox, ry + oy)

    def hitter_pos(self):
        # batter sprinting to 1B while the ball is in play; slides around
        # any runner already holding a base so figures never overlap
        b = self.ball_play
        p = min(1.0, b["t"] / max(0.01, b["dur"]))
        bp = min(1.0, p * 1.5)
        bp = bp * bp * (3 - 2 * bp)  # eased: burst out, settle onto the bag
        hx, hy = self.base_point(0)
        fx, fy = self.base_point(1)
        hx = hx + (fx - hx) * bp
        hy = hy + (fy - hy) * bp
        for i, occ in enumerate(self.bases):
            if occ:
                lx, ly = self.base_lead(i)
                dx, dy = hx - lx, hy - ly
                d = math.hypot(dx, dy)
                if d < px(26) and d > 0.01:
                    hx = lx + dx / d * px(26)
                    hy = ly + dy / d * px(26)
        return (hx, hy)

    def separate_fielders(self):
        # yield auto fielders (never the pitcher or your controlled one)
        # away from the hitter / animated runners so nobody overlaps.
        # The drawn pitcher always holds the mound, so everyone keeps off it.
        spots = [(MOUND[0], MOUND[1] - px(22))]
        if self.state == "hit" and self.ball_play and self.ball_play["kind"] != "OUT":
            hx, hy = self.hitter_pos()
            spots.append((hx, hy - px(18)))
        elif self.state == "runners":
            for anim in self.runners_anim:
                x, y = self.runner_pos(anim)
                spots.append((x, y - px(18)))
        if not spots:
            return
        for i, f in enumerate(self.fielders):
            if i == 0 or i == self.player_fielder:
                continue
            for (sx, sy) in spots:
                dx, dy = f[0] - sx, f[1] - sy
                d = math.hypot(dx, dy)
                if d < px(26):
                    if d < 0.01:
                        dx, dy, d = 1.0, 0.0, 1.0
                    f[0] = sx + dx / d * px(26)
                    f[1] = sy + dy / d * px(26)

    def advance_walk(self):
        # force runners — returns moves for animation, updates bases/score
        b = self.bases[:]
        moves = []
        scored = False
        if b[0] and b[1] and b[2]:
            # bases loaded: 3B scores, 2B->3B, 1B->2B, batter->1B
            moves = [(3, 4), (2, 3), (1, 2), (0, 1)]
            self.score[0 if self.top else 1] += 1
            scored = True
            self.bases = [True, True, True]
        elif b[0] and b[1]:
            moves = [(2, 3), (1, 2), (0, 1)]
            self.bases = [True, True, True]
        elif b[0]:
            moves = [(1, 2), (0, 1)]
            self.bases = [True, True, False]
        else:
            moves = [(0, 1)]
            self.bases = [True, b[1], b[2]]
        return moves, scored

    def apply_hit(self, kind, offense=None):
        """kind: '1B','2B','3B','HR' — advance runners, return (runs, moves)."""
        runs = 0
        b = self.bases[:]
        is_cpu = self.top if offense is None else (offense == "cpu")
        team = 0 if is_cpu else 1
        moves = []
        if kind == "1B":
            if b[2]:
                runs += 1
                moves.append((3, 4))
                b[2] = False
            if b[1]:
                moves.append((2, 3))
                b[2] = True
                b[1] = False
            if b[0]:
                moves.append((1, 2))
                b[1] = True
            moves.append((0, 1))
            b[0] = True
        elif kind == "2B":
            for i in (2, 1):
                if b[i]:
                    runs += 1
                    moves.append((i + 1, 4))
                    b[i] = False
            if b[0]:
                runs += 1
                moves.append((1, 4))
                b[0] = False
            moves.append((0, 2))
            b[1] = True
        elif kind == "3B":
            for i in (2, 1, 0):
                if b[i]:
                    runs += 1
                    moves.append((i + 1, 4))
                    b[i] = False
            moves.append((0, 3))
            b = [False, False, True]
        elif kind == "HR":
            for i in (2, 1, 0):
                if b[i]:
                    runs += 1
                    moves.append((i + 1, 4))
            moves.append((0, 4))
            runs = sum(1 for x in self.bases if x) + 1
            b = [False, False, False]
        self.bases = b
        self.score[team] += runs
        return runs, moves

    # ---------- pitching (you) ----------
    def throw_player_pitch(self):
        # aim is mouse pos clamped near zone, meter affects speed/error
        tx, ty = self.aim
        err = (1.0 - self.meter_value) * px(70) + px(8)
        tx += random.gauss(0, err * 0.5)
        ty += random.gauss(0, err * 0.5)
        speed = px(5) + self.meter_value * px(7)  # px/frame toward plate
        in_zone = STRIKE_ZONE.collidepoint(tx, ty)
        d = self.diff()
        # CPU swing decision (harder modes chase more + time better)
        swing_prob = d["swing_in"] if in_zone else d["swing_out"]
        will_swing = random.random() < swing_prob
        # CPU timing skill
        timing_err = random.gauss(0, d["cpu_timing_sd"])  # seconds
        self.pitch = {
            "x": float(MOUND[0]), "y": float(MOUND[1]),
            "tx": tx, "ty": ty, "speed": speed,
            "will_swing": will_swing,
            "timing_err": timing_err, "swung": False,
            "in_zone": in_zone,
        }
        self.state = "pitch_live"

    def update_player_pitch_live(self, dt):
        p = self.pitch
        # move toward target
        dx, dy = p["tx"] - p["x"], p["ty"] - p["y"]
        dist = math.hypot(dx, dy)
        step = p["speed"] * 60 * dt
        if dist <= step + px(4):
            # arrived at plate
            self.resolve_player_pitch(p)
            return
        p["x"] += dx / dist * step
        p["y"] += dy / dist * step
        # CPU swing timing: swing when ball ~85% there + error
        progress = 1 - dist / max(1, math.hypot(p["tx"] - MOUND[0], p["ty"] - MOUND[1]))
        if p["will_swing"] and not p["swung"] and progress > 0.82 + p["timing_err"]:
            p["swung"] = True
            self.bat_anim = 0.0001  # swing animation for the CPU batter
            self.resolve_cpu_swing(p)

    def resolve_cpu_swing(self, p):
        # contact quality based on pitch difficulty + randomness + mode bonus
        q = random.random() + self.diff()["contact_bonus"]
        # harder to hit high power pitches
        power_factor = (p["speed"] - px(5)) / float(px(7))
        q -= power_factor * 0.12
        if not p["in_zone"]:
            q -= 0.25
        if q < 0.28:
            self.strikes += 1
            if self.strikes >= 3:
                self.say("Strikeout!", "CPU down!")
                self.add_out()
            else:
                self.say(f"Swing & miss! {self.count_str()}")
                self.state = "pitch"
            self.pitch = None
        elif q < 0.45:
            # foul / miss -> strike (unless 2 strikes, stays)
            if self.strikes < 2:
                self.strikes += 1
            self.say(f"Foul ball. {self.count_str()}")
            self.pitch = None
            self.state = "pitch"
        else:
            # contact! pick outcome
            r = random.random()
            if r < 0.30:
                self.begin_contact(offense="cpu", quality=q)
            elif r < 0.55:
                # grounder out / hit
                if random.random() < 0.55:
                    self.begin_contact(offense="cpu", quality=q - 0.15)
                else:
                    self.say("Groundout!", "Nice pitch.")
                    self.add_out()
            elif r < 0.70:
                if self.strikes < 2:
                    self.strikes += 1
                self.say(f"Foul. {self.count_str()}")
                self.pitch = None
                self.state = "pitch"
            else:
                self.begin_contact(offense="cpu", quality=q + 0.1)

    def resolve_player_pitch(self, p):
        # CPU didn't swing (or swing handled) -> ball/strike call
        if p["swung"]:
            return  # already resolved
        if p["in_zone"]:
            self.strikes += 1
            if self.strikes >= 3:
                self.say("Called strike 3! Strikeout!")
                self.add_out()
            else:
                self.say(f"Called strike. {self.count_str()}")
                self.state = "pitch"
        else:
            self.balls += 1
            if self.balls >= 4:
                moves, scored = self.advance_walk()
                sub = "Run scores!" if scored else ("Bases loaded!" if all(self.bases) else "Batter to 1B")
                if scored:
                    self.celebrate_runs("cpu", big=False)
                self.start_runner_sequence(moves, "Ball 4 - CPU walks.", sub)
                self.pitch = None
                return
            else:
                self.say(f"Ball. {self.count_str()}")
                self.state = "pitch"
        self.pitch = None

    # ---------- batting (CPU pitches, you hit) ----------
    def start_cpu_pitch(self):
        # pick target, speed, windup — mode sets how hittable it is
        d = self.diff()
        in_zone = random.random() < d["zone_prob"]
        if in_zone:
            tx = random.randint(STRIKE_ZONE.x + px(8), STRIKE_ZONE.right - px(8))
            ty = random.randint(STRIKE_ZONE.y + px(8), STRIKE_ZONE.bottom - px(8))
        else:
            tx = W // 2 + random.choice([-1, 1]) * random.randint(px(55), px(110))
            ty = STRIKE_ZONE.y + random.randint(-px(20), px(120))
        lo, hi = d["cpu_pitch"]
        speed = random.uniform(lo, hi)  # px/sec
        self.cpu_pitch = {"x": float(MOUND[0]), "y": float(MOUND[1]),
                          "tx": tx, "ty": ty, "speed": speed,
                          "in_zone": in_zone}
        wlo, whi = d["windup"]
        self.windup_t = random.uniform(wlo, whi)
        self.pitch_coming = False
        self.swing_done = False
        self.bat_power = 0.0
        self.bat_charging = False
        self.bat_dir = 1
        self.state = "batwait"

    def update_cpu_pitch(self, dt):
        if self.windup_t > 0:
            self.windup_t -= dt
            if self.windup_t <= 0:
                self.pitch_coming = True
            return
        if not self.pitch_coming or self.cpu_pitch is None:
            return
        c = self.cpu_pitch
        dx, dy = c["tx"] - c["x"], c["ty"] - c["y"]
        dist = math.hypot(dx, dy)
        step = c["speed"] * dt
        if dist <= step + px(3):
            c["x"], c["y"] = c["tx"], c["ty"]
            self.resolve_take()  # you didn't swing
            return
        c["x"] += dx / dist * step
        c["y"] += dy / dist * step

    def player_swing(self, power):
        if self.state != "batwait" or self.swing_done:
            return
        self.swing_done = True
        self.bat_charging = False
        self.bat_anim = 0.0001  # swing animation for the Player batter
        power = max(0.0, min(1.0, power))
        c = self.cpu_pitch
        keys = pygame.key.get_pressed()
        aim_up = keys[pygame.K_UP]
        if c is None or not self.pitch_coming:
            # way early
            self.strikes += 1
            if self.strikes >= 3:
                self.say("Struck out! (too early)")
                self.add_out()
            else:
                self.say(f"Swing & miss! {self.count_str()}")
                self.start_cpu_pitch_keep_count()
            return
        # timing: distance remaining to plate (windows widen in easy mode)
        dist = math.hypot(c["tx"] - c["x"], c["ty"] - c["y"])
        # power bonus: full power adds ~+0.18, tap adds ~-0.17
        pbonus = (power - 0.5) * 0.35
        # placement: cursor on the ball boosts contact, way off hurts it
        dcursor = math.hypot(c["x"] - self.bat_aim[0], c["y"] - self.bat_aim[1])
        if dcursor <= px(32):
            pbonus += 0.10
        elif dcursor > px(68):
            pbonus -= 0.15
        perfect, foul = self.diff()["perfect"], self.diff()["foul"]
        if dist < perfect:
            quality = max(0.05, min(1.05, 1.0 - dist / (perfect * 1.25) + pbonus))
            self.contact(quality, aim_up)
        elif dist < foul:
            quality = max(0.05, min(1.0, 0.55 + pbonus))
            r = random.random()
            if r < 0.5:
                self.contact(quality, aim_up)
            else:
                if self.strikes < 2:
                    self.strikes += 1
                self.say(f"Foul ball! {self.count_str()}", "Just late/early.")
                self.start_cpu_pitch_keep_count()
        else:
            self.strikes += 1
            if self.strikes >= 3:
                self.say("Struck out swinging!")
                self.add_out()
            else:
                self.say(f"Swing & miss! {self.count_str()}")
                self.start_cpu_pitch_keep_count()

    def start_cpu_pitch_keep_count(self):
        b, s = self.balls, self.strikes
        self.start_cpu_pitch()
        self.balls, self.strikes = b, s

    def resolve_take(self):
        c = self.cpu_pitch
        if self.swing_done:
            return
        # held SPACE too long without releasing = take
        self.bat_charging = False
        if c["in_zone"]:
            self.strikes += 1
            if self.strikes >= 3:
                self.say("Called strike 3! You're out.")
                self.add_out()
            else:
                self.say(f"Called strike. {self.count_str()}")
                self.start_cpu_pitch_keep_count()
        else:
            self.balls += 1
            if self.balls >= 4:
                moves, scored = self.advance_walk()
                sub = "Run scores!" if scored else ("Bases loaded!" if all(self.bases) else "Batter to 1B")
                if scored:
                    self.celebrate_runs("you", big=False)
                self.start_runner_sequence(moves, "Walk! Take your base.", sub)
                return
            else:
                self.say(f"Ball. {self.count_str()}")
                self.start_cpu_pitch_keep_count()

    def contact(self, quality, aim_up):
        # adjust by aim
        q = quality + random.uniform(-0.1, 0.1)
        if aim_up:
            q += 0.08
        r = random.random()
        if q > 0.85 and r < 0.35:
            self.begin_contact(offense="you", quality=1.0)
        elif q > 0.6:
            # solid contact
            if r < 0.62:
                self.begin_contact(offense="you", quality=q)
            elif r < 0.75:
                if self.strikes < 2:
                    self.strikes += 1
                self.say(f"Foul. {self.count_str()}")
                self.start_cpu_pitch_keep_count()
            else:
                self.begin_contact(offense="you", quality=q - 0.2)
        elif q > 0.4:
            if r < 0.45:
                self.begin_contact(offense="you", quality=q - 0.25)
            elif r < 0.65:
                self.say("Groundout!", "Right at 'em.")
                self.add_out()
            else:
                if self.strikes < 2:
                    self.strikes += 1
                self.say(f"Fouled off. {self.count_str()}")
                self.start_cpu_pitch_keep_count()
        else:
            # weak
            if r < 0.5:
                self.say("Popped out!" if aim_up else "Groundout!")
                self.add_out()
            else:
                if self.strikes < 2:
                    self.strikes += 1
                self.say(f"Foul. {self.count_str()}")
                self.start_cpu_pitch_keep_count()

    def count_str(self):
        return f"{self.balls}-{self.strikes}, {self.outs} out"

    # ---------- ball in play ----------
    def begin_contact(self, offense, quality):
        # brief "crack of the bat" beat so the swing is seen on every hit
        # before the ball launches and the hitter runs
        self.pending_hit = (offense, quality)
        self.contact_t = 0.0
        self.say("Contact!", "Here comes the ball..." if offense == "you" else "CPU connects!")
        self.state = "contact"

    def update_contact(self, dt):
        self.contact_t += dt
        if self.contact_t >= 0.22 and self.pending_hit:
            offense, quality = self.pending_hit
            self.pending_hit = None
            self.start_ball_in_play(offense, quality)

    def start_ball_in_play(self, offense, quality):
        # decide outcome, then animate to match
        r = random.random()
        if quality >= 0.95:
            kind = "HR" if r < 0.45 else ("3B" if r < 0.55 else ("2B" if r < 0.75 else "1B"))
        elif quality >= 0.7:
            kind = "HR" if r < 0.12 else ("3B" if r < 0.2 else ("2B" if r < 0.42 else ("1B" if r < 0.78 else "OUT")))
        elif quality >= 0.5:
            kind = "1B" if r < 0.42 else ("2B" if r < 0.52 else "OUT")
        else:
            kind = "1B" if r < 0.18 else "OUT"
        # landing spot — keep catches/hits on the field (wall bottom y=398);
        # HRs fly into the stands on purpose
        if kind == "HR":
            lx = W // 2 + random.uniform(-px(320), px(320))
            ly = random.uniform(px(80), px(140))
        elif kind == "OUT":
            # fly to a fielder
            lx = W // 2 + random.uniform(-px(220), px(220))
            ly = random.uniform(px(195), px(360))
        else:
            lx = W // 2 + random.uniform(-px(300), px(300))
            ly = random.uniform(px(200), px(330)) if kind in ("1B", "2B") else random.uniform(px(190), px(240))
            # ensure gap: push away from fielders a bit
        sx, sy = HOME[0], HOME[1] - px(40)
        self.ball_play = {"x": float(sx), "y": float(sy), "lx": lx, "ly": ly,
                          "t": 0.0, "dur": 1.4 if kind == "HR" else 1.1,
                          "kind": kind, "offense": offense}
        # fielders: P, 1B, 2B, SS, 3B, LF, CF, RF. Only the two drawn
        # fielders nearest the landing spot chase it (like real baseball);
        # everyone else holds — no more five-man pile-ups.
        self.fielders = self.default_field_positions()
        self.player_fielder = 6 if offense == "cpu" else -1  # you control CF when defending
        chasers = sorted(
            (i for i in range(len(self.fielders)) if i != 0 and i != self.player_fielder),
            key=lambda i: abs(self.fielders[i][0] - lx) + abs(self.fielders[i][1] - ly),
        )[:2]
        self.ball_play["chasers"] = chasers
        self.state = "hit"
        self.say("Ball in play!", "Arrows/WASD to move fielder!" if offense == "cpu" else "")

    def update_hit(self, dt, keys):
        b = self.ball_play
        b["t"] += dt
        p = min(1.0, b["t"] / b["dur"])
        sx, sy = HOME[0], HOME[1] - px(40)
        # arc: lerp + height bump
        b["x"] = sx + (b["lx"] - sx) * p
        b["y"] = sy + (b["ly"] - sy) * p - math.sin(p * math.pi) * px(120)
        cpu_f, pl_f = self.diff()["cpu_field"], self.diff()["player_field"]
        # the sprinting hitter holds this space: autos yield instead of
        # fighting the separation push (that fight caused hovering/jitter)
        hold = None
        if b["kind"] != "OUT":
            hx, hy = self.hitter_pos()
            hold = (hx, hy - px(18))
        # move fielders toward landing (CPU) or player-controlled one fielder
        for i, f in enumerate(self.fielders):
            if i == self.player_fielder:
                sp = pl_f * dt
                if keys[pygame.K_LEFT] or keys[pygame.K_a]:
                    f[0] -= sp
                if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
                    f[0] += sp
                if keys[pygame.K_UP] or keys[pygame.K_w]:
                    f[1] -= sp
                if keys[pygame.K_DOWN] or keys[pygame.K_s]:
                    f[1] += sp
                f[0] = max(px(20), min(W - px(20), f[0]))
                f[1] = max(px(180), min(H - px(80), f[1]))  # never into the stands
            else:
                if hold is not None and math.hypot(f[0] - hold[0], f[1] - hold[1]) < px(34):
                    continue  # yield to the hitter; separation keeps spacing
                # only the two nearest break for the ball; others hold ground
                if b.get("chasers") is not None and i not in b["chasers"]:
                    continue
                # auto-fielders chase the landing spot
                dx, dy = b["lx"] - f[0], b["ly"] - f[1]
                d = math.hypot(dx, dy)
                if d > px(8):
                    sp = (cpu_f if b["offense"] == "you" else px(215)) * dt
                    f[0] += dx / d * min(sp, d)
                    f[1] += dy / d * min(sp, d)
        # keep converging fielders from stacking on each other (pitcher is
        # drawn separately and your fielder is yours — neither gets pushed).
        # Two relaxation passes beat the per-frame chase pulling them together.
        auto = [f for i, f in enumerate(self.fielders)
                if i != 0 and i != self.player_fielder]
        for _ in range(2):
            for a in range(len(auto)):
                for b_ in range(a + 1, len(auto)):
                    dx = auto[b_][0] - auto[a][0]
                    dy = auto[b_][1] - auto[a][1]
                    d = math.hypot(dx, dy)
                    if d < px(27):
                        if d < 0.01:
                            dx, dy, d = 1.0, 0.0, 1.0
                        push = (px(27) - d) / 2
                        ux, uy = dx / d, dy / d
                        auto[a][0] -= ux * push
                        auto[a][1] -= uy * push
                        auto[b_][0] += ux * push
                        auto[b_][1] += uy * push
        # wall bottom is 398: autos stop at the wall, never enter the stands
        self.separate_fielders()
        for i, f in enumerate(self.fielders):
            if i != 0 and i != self.player_fielder:
                f[0] = max(px(20), min(W - px(20), f[0]))
                f[1] = max(f[1], px(180))
        if p >= 1.0:
            self.resolve_hit()

    def celebrate_runs(self, offense, big):
        # left half = Player fans, right half = CPU fans; small for run
        # scoring plays, big (arms up, longer) only for home runs
        self.crowd_celebrate = "you" if offense == "you" else "cpu"
        self.crowd_big = big
        self.crowd_timer = 4.0 if big else 2.0
        # agent experiment: white flash + banner on home runs (discarded)
        if big:
            self.hr_flash = 1.0
            self.hr_banner = "HOME RUN!"
        else:
            self.hr_banner = ""

    def resolve_hit(self):
        b = self.ball_play
        kind = b["kind"]
        offense_you = b["offense"] == "you"
        who = "Player" if offense_you else "CPU"
        # where the sprint ended: the batter's run continues from here
        hstart = self.hitter_pos()
        if kind == "OUT":
            # check diving/player catch bonus when defending
            if b["offense"] == "cpu" and self.player_fielder >= 0:
                f = self.fielders[self.player_fielder]
                d = math.hypot(f[0] - b["lx"], f[1] - b["ly"])
                if d > px(90):
                    # you misplayed it -> turns into a hit!
                    kind = random.choice(["1B", "2B", "1B"])
                    runs, moves = self.apply_hit(kind, offense=b["offense"])
                    label = {"1B": "Single!", "2B": "Double!"}[kind]
                    if runs > 0:
                        self.celebrate_runs(b["offense"], big=False)
                    self.start_runner_sequence(
                        moves, f"{who}: {label} (misplayed!)",
                        f"+{runs} run(s)!" if runs else "Runner advances.",
                        dur=1.8, batter_start=hstart)
                    return
            self.say(f"{who} flied out!", "Caught!")
            self.add_out()
            return
        runs, moves = self.apply_hit(kind, offense=b["offense"])
        label = {"1B": "Single!", "2B": "Double!", "3B": "Triple!", "HR": "HOME RUN!!"}[kind]
        if runs > 0:
            self.celebrate_runs(b["offense"], big=(kind == "HR"))
        self.start_runner_sequence(
            moves, f"{who}: {label}",
            f"+{runs} run(s)! Watch them run!" if runs else "Runner advances to next base.",
            dur=2.6 if kind == "HR" else 1.8, batter_start=hstart)

    def after_at_bat(self):
        self.ball_play = None
        self.runners_anim = []
        self.new_batter()
        # check game over (walkoff / innings done)
        if self.inning > self.max_innings() and self.score[0] != self.score[1]:
            self.state = "gameover"
            return
        self.state = "pitch" if self.top else "batwait"
        if self.state == "batwait":
            self.start_cpu_pitch()

    # ---------- draw ----------
    def build_static_bg(self):
        # One-time render of everything that never moves: grass, stands
        # (without the crowd), and the outfield wall. The crowd is drawn
        # fresh every frame so each fan appears exactly once, seated or not.
        bg = pygame.Surface((W, H)).convert()
        bg.fill(GREEN_D)
        for i in range(6):
            y = px(40) + i * px(90)
            if i % 2 == 0:
                pygame.draw.rect(bg, GREEN_L, (0, y, W, px(45)))
        pygame.draw.rect(bg, STAND_BG, (0, px(64), W, px(92)))
        for ry in (px(84), px(106), px(128), px(148)):
            pygame.draw.rect(bg, (70, 70, 90), (0, ry, W, px(4)))
        # wall height hand-tuned to fit the text with even margins
        pygame.draw.rect(bg, (30, 60, 140), (0, px(156), W, 52))
        pygame.draw.rect(bg, WHITE, (0, px(156), W, 52), px(2))
        wt = self.wall_font.render("HOME RUN WALL  •  ARCADE STADIUM  •  380 FT", True, WHITE)
        bg.blit(wt, (W // 2 - wt.get_width() // 2, 356))  # optically centered
        self.bg = bg

    def draw_field(self):
        s = self.screen
        s.blit(self.bg, (0, 0))
        # agent experiment: HR white-flash overlay + banner (discarded:
        # it never faded and washed out the field on every homer)
        if self.hr_flash > 0:
            flash = pygame.Surface((W, H), pygame.SRCALPHA)
            flash.fill((255, 255, 255, int(120 * self.hr_flash)))
            s.blit(flash, (0, 0))
            if self.hr_banner:
                bt = self.big.render(self.hr_banner, True, YELLOW)
                s.blit(bt, (W // 2 - bt.get_width() // 2, px(300)))
        # crowd: seated fans first, then celebrators on top so jumpers
        # correctly overlap (never duplicate) anyone behind them.
        # Big HR celebration: high bounce with arms up and rings.
        # Small run-scoring one: gentle bounce only.
        if self.crowd_celebrate:
            tnow = pygame.time.get_ticks() / 1000.0
            amp = px(9) if self.crowd_big else px(4)
            for (cx, cy, cc) in self.crowd:
                is_left = cx < W // 2
                if ((self.crowd_celebrate == "you" and is_left) or
                        (self.crowd_celebrate == "cpu" and not is_left)):
                    continue
                pygame.draw.circle(s, cc, (cx, cy), px(4))
                pygame.draw.circle(s, BLACK, (cx, cy), px(4), px(1))
            for (cx, cy, cc) in self.crowd:
                is_left = cx < W // 2
                if not ((self.crowd_celebrate == "you" and is_left) or
                        (self.crowd_celebrate == "cpu" and not is_left)):
                    continue
                bounce = abs(math.sin(tnow * 10 + cx * 0.05)) * amp
                cy -= bounce
                if self.crowd_big:
                    pygame.draw.line(s, cc, (cx - px(4), cy - px(4)), (cx - px(7), cy - px(10)), px(2))
                    pygame.draw.line(s, cc, (cx + px(4), cy - px(4)), (cx + px(7), cy - px(10)), px(2))
                pygame.draw.circle(s, cc, (int(cx), int(cy)), px(5))
                if self.crowd_big:
                    pygame.draw.circle(s, YELLOW, (int(cx), int(cy)), px(5), px(1))
        else:
            for (cx, cy, cc) in self.crowd:
                pygame.draw.circle(s, cc, (cx, cy), px(4))
                pygame.draw.circle(s, BLACK, (cx, cy), px(4), px(1))
        # dirt diamond
        pygame.draw.polygon(s, BROWN, [HOME, BASE1, BASE2, BASE3])
        pygame.draw.polygon(s, WHITE, [HOME, BASE1, BASE2, BASE3], px(3))
        # pitcher's mound — layered + rubber for visibility
        pygame.draw.ellipse(s, (120, 80, 45), (MOUND[0] - px(38), MOUND[1] - px(18), px(76), px(36)))
        pygame.draw.ellipse(s, BROWN, (MOUND[0] - px(30), MOUND[1] - px(14), px(60), px(28)))
        pygame.draw.ellipse(s, (200, 150, 100), (MOUND[0] - px(18), MOUND[1] - px(9), px(36), px(18)))
        pygame.draw.rect(s, WHITE, (MOUND[0] - px(12), MOUND[1] - px(4), px(24), px(5)))
        # home area — big dirt circle, plate, batter boxes, catcher box
        pygame.draw.ellipse(s, (120, 80, 45), (HOME[0] - px(70), HOME[1] - px(38), px(140), px(76)))
        pygame.draw.ellipse(s, BROWN, (HOME[0] - px(55), HOME[1] - px(30), px(110), px(60)))
        # batter boxes
        pygame.draw.rect(s, WHITE, (HOME[0] - px(62), HOME[1] - px(28), px(30), px(40)), px(2))
        pygame.draw.rect(s, WHITE, (HOME[0] + px(32), HOME[1] - px(28), px(30), px(40)), px(2))
        # catcher's box — deep enough to hold the whole crouched catcher
        pygame.draw.rect(s, WHITE, (HOME[0] - px(27), HOME[1] + px(7), px(54), px(45)), px(2))
        # bases
        for i, base in enumerate([None, BASE1, BASE2, BASE3]):
            if i == 0:
                continue
            bx, by = [BASE1, BASE2, BASE3][i - 1]
            pygame.draw.rect(s, WHITE, (bx - px(9), by - px(9), px(18), px(18)))
            pygame.draw.rect(s, BLACK, (bx - px(9), by - px(9), px(18), px(18)), px(2))
        # strike zone + plate
        pygame.draw.polygon(s, WHITE, [(HOME[0] - px(22), HOME[1]), (HOME[0] + px(22), HOME[1]),
                                       (HOME[0] + px(14), HOME[1] + px(14)), (HOME[0] - px(14), HOME[1] + px(14))])
        if self.state in ("batwait", "pitch", "pitch_live"):
            # single black outline: 4.3+:1 on dirt for every kind of
            # color vision (achromatic beats any hue here)
            pygame.draw.rect(s, BLACK, STRIKE_ZONE, px(2))

    def draw_actors(self):
        s = self.screen
        off_col = RED if self.top else BLUE    # batting team
        def_col = BLUE if self.top else RED    # fielding team
        GLOVE = (139, 90, 43)
        GLOVE_D = (90, 55, 25)
        BAT = (210, 170, 110)
        BAT_D = (120, 85, 40)

        def glove(x, y, r=px(8), raised=False):
            # pre-rendered sprite: identical pixels to drawing it fresh,
            # without ~27 ellipse primitives per frame
            key = (r, raised)
            spr = self._gloves.get(key)
            if spr is None:
                h = px(2) if raised else 0
                pad = px(1)
                spr = pygame.Surface((r * 2 + pad * 2, r * 2 + pad * 2), pygame.SRCALPHA)
                pygame.draw.ellipse(spr, GLOVE, (pad, pad, r * 2, r * 2 - h))
                pygame.draw.ellipse(spr, GLOVE_D, (pad, pad, r * 2, r * 2 - h), px(2))
                pygame.draw.line(spr, GLOVE_D, (pad + px(3), r - px(1)), (pad + r * 2 - px(3), r - px(1)), px(1))
                self._gloves[key] = spr
            s.blit(spr, (int(x - r - px(1)), int(y - r - px(1))))

        def bat(x1, y1, x2, y2):
            w = px(7)
            pygame.draw.line(s, BAT_D, (x1, y1), (x2, y2), w)
            pygame.draw.line(s, BAT, (x1, y1), (x2, y2), px(4))
            pygame.draw.circle(s, BAT_D, (int(x1), int(y1)), px(4))  # knob
            pygame.draw.circle(s, BAT_D, (int(x2), int(y2)), w // 2)  # rounded barrel end
            pygame.draw.circle(s, BAT, (int(x2), int(y2)), px(4) // 2)

        # pitcher (defense, on visible mound) + glove
        pygame.draw.circle(s, def_col, (int(MOUND[0]), int(MOUND[1]) - px(22)), px(12))
        pygame.draw.rect(s, BLACK, (MOUND[0] - px(8), MOUND[1] - px(12), px(16), px(22)))
        pygame.draw.circle(s, WHITE, (int(MOUND[0]), int(MOUND[1]) - px(22)), px(12), px(2))
        pitching = self.state in ("pitch", "pitch_live")
        glove(MOUND[0] - px(16), MOUND[1] - px(8), r=px(9), raised=pitching)
        # catcher (defense, crouched behind plate, fully inside the box)
        pygame.draw.circle(s, def_col, (HOME[0], HOME[1] + px(26)), px(10))
        pygame.draw.rect(s, BLACK, (HOME[0] - px(7), HOME[1] + px(32), px(14), px(14)))
        # catcher's glove up when pitch is coming
        if (self.state == "batwait" and self.pitch_coming) or self.state == "pitch_live":
            glove(HOME[0] - px(20), HOME[1] - px(8), r=px(9), raised=True)
        else:
            glove(HOME[0] + px(16), HOME[1] + px(18), r=px(7))
        # umpire in the slot: opposite side from the batter, clear of the box
        uside = 1 if not self.top else -1
        ux = HOME[0] + uside * px(43)
        pygame.draw.circle(s, BLACK, (int(ux), HOME[1] + px(44)), px(9))
        pygame.draw.rect(s, (50, 50, 50), (ux - px(7), HOME[1] + px(51), px(14), px(15)))
        # batter / hitter — during runners & hit the hitter himself runs, no static figure at plate
        if self.state == "runners":
            pass  # hitter is one of runners_anim (0 -> 1B...), drawn below
        elif self.state == "hit" and self.ball_play and self.ball_play["kind"] != "OUT":
            # hitter sprinting to 1B while ball is in play (slides around holders)
            rx, ry = self.hitter_pos()
            pygame.draw.circle(s, off_col, (int(rx), int(ry) - px(18)), px(11))
            pygame.draw.circle(s, WHITE, (int(rx), int(ry) - px(18)), px(11), px(2))
        else:
            bx = HOME[0] + (-px(40) if (not self.top) else px(40))
            pygame.draw.circle(s, off_col, (int(bx), int(HOME[1]) - px(45)), px(12))
            pygame.draw.rect(s, BLACK, (bx - px(8), HOME[1] - px(35), px(16), px(24)))
            # baseball bat — animated swing, else ready stance
            side = -1 if not self.top else 1
            if 0 < self.bat_anim <= 0.35 and self.state in ("batwait", "pitch_live", "pitch", "contact"):
                p = min(1.0, self.bat_anim / 0.35)
                base = math.atan2(-px(38), side * px(22))
                sweep = 1.6 if side == -1 else -1.6
                hx, hy = bx, HOME[1] - px(30)
                for gp, gw in ((p - 0.18, px(2)), (p - 0.09, px(3))):
                    if gp > 0:
                        ge = 1 - (1 - gp) ** 2
                        ga = base + sweep * ge
                        gx, gy = hx + px(44) * math.cos(ga), hy + px(44) * math.sin(ga)
                        pygame.draw.line(s, BAT, (hx, hy), (gx, gy), gw)
                        pygame.draw.circle(s, BAT, (int(gx), int(gy)), gw // 2)
                e = 1 - (1 - p) ** 2
                ang = base + sweep * e
                bat(hx, hy, hx + px(44) * math.cos(ang), hy + px(44) * math.sin(ang))
            else:
                bat(bx, HOME[1] - px(30), bx + side * px(22), HOME[1] - px(68))
        # on-deck hitter — same team, waiting behind the current batter (never by the bases);
        # plain figure with no rings/outlines around them
        batter_off = -px(40) if not self.top else px(40)
        ox, oy = HOME[0] + batter_off * 1.9, HOME[1] + px(58)
        pygame.draw.circle(s, off_col, (int(ox), int(oy) - px(12)), px(9))
        pygame.draw.rect(s, BLACK, (ox - px(6), oy - px(6), px(12), px(14)))
        bat(ox + px(6), oy - px(8), ox + px(18), oy - px(30))
        # stationary baserunners (offense, white ring) — hidden during run anim;
        # offset off the bag (taking a lead) so they never stack on fielders;
        # the 2B runner takes a bigger lead toward 3B to clear centered CF
        if self.state != "runners":
            for i, occ in enumerate(self.bases):
                if occ:
                    rx, ry = self.base_lead(i)
                    pygame.draw.circle(s, off_col, (int(rx), int(ry) - px(18)), px(10))
                    pygame.draw.circle(s, WHITE, (int(rx), int(ry) - px(18)), px(10), px(2))
        else:
            # animated runners going to next base / scoring
            for anim in self.runners_anim:
                x, y = self.runner_pos(anim)
                c = RED if anim["offense_cpu"] else BLUE
                pygame.draw.circle(s, c, (int(x), int(y) - px(18)), px(11))
                pygame.draw.circle(s, WHITE, (int(x), int(y) - px(18)), px(11), px(2))
                if anim["scored"]:
                    t = self.small.render("RUN!", True, YELLOW)
                    s.blit(t, (int(x) - px(18), int(y) - px(48)))
        # fielders — always visible (defense) with gloves; highlighted + controllable on hit.
        # index 0 is the pitcher, drawn separately above with body + glove, so skip it here.
        for i, f in enumerate(self.fielders):
            if i == 0:
                continue
            pygame.draw.circle(s, def_col, (int(f[0]), int(f[1])), px(11))
            # black trim: highest contrast on grass for every kind of color vision
            pygame.draw.circle(s, BLACK, (int(f[0]), int(f[1])), px(11), px(2))
            glove(f[0] + px(12), f[1] + px(4), r=px(6))
            if self.state == "hit" and i == self.player_fielder:
                # yellow marker above the fielder you control (no recolor, no ring)
                mx, my = int(f[0]), int(f[1])
                pygame.draw.polygon(s, YELLOW, [(mx - px(14), my - px(54)),
                                               (mx + px(14), my - px(54)),
                                               (mx, my - px(32))])
        # pitches — ball grows as it comes toward the batter (perspective)
        if self.state == "pitch_live" and self.pitch:
            p = self.pitch
            tot = max(1, math.hypot(p["tx"] - MOUND[0], p["ty"] - MOUND[1]))
            prog = max(0.0, min(1.0, 1 - math.hypot(p["tx"] - p["x"], p["ty"] - p["y"]) / tot))
            r = int(px(4.5) + (px(10) - px(4.5)) * prog)
            pygame.draw.circle(s, WHITE, (int(p["x"]), int(p["y"])), r)
            pygame.draw.circle(s, BLACK, (int(p["x"]), int(p["y"])), r, px(2))
        if self.state == "batwait" and self.cpu_pitch and self.pitch_coming:
            c = self.cpu_pitch
            tot = max(1, math.hypot(c["tx"] - MOUND[0], c["ty"] - MOUND[1]))
            prog = max(0.0, min(1.0, 1 - math.hypot(c["tx"] - c["x"], c["ty"] - c["y"]) / tot))
            r = int(px(4.5) + (px(10) - px(4.5)) * prog)
            pygame.draw.circle(s, WHITE, (int(c["x"]), int(c["y"])), r)
            pygame.draw.circle(s, BLACK, (int(c["x"]), int(c["y"])), r, px(2))
        # batted ball with shadow
        if self.state == "hit" and self.ball_play:
            b = self.ball_play
            pygame.draw.ellipse(s, (0, 0, 0, 60), (b["x"] - px(10), b["y"] + px(25), px(20), px(7)))
            pygame.draw.circle(s, WHITE, (int(b["x"]), int(b["y"])), px(8))
            pygame.draw.circle(s, RED, (int(b["x"]), int(b["y"])), px(8), px(1))
        # aim marker when pitching
        if self.state == "pitch":
            pygame.draw.circle(s, YELLOW, (int(self.aim[0]), int(self.aim[1])), px(8), px(2))
            pygame.draw.line(s, YELLOW, (self.aim[0] - px(14), self.aim[1]), (self.aim[0] + px(14), self.aim[1]), px(1))
            pygame.draw.line(s, YELLOW, (self.aim[0], self.aim[1] - px(14)), (self.aim[0], self.aim[1] + px(14)), px(1))
        # batting cursor: where you aim (mouse), like the pitching cursor
        if self.state == "batwait":
            cx, cy = self.bat_aim
            r = px(11) if self.bat_charging else px(8)
            pygame.draw.circle(s, WHITE, (int(cx), int(cy)), r, px(2))
            pygame.draw.line(s, BAT, (cx - px(14), cy), (cx + px(14), cy), px(2))
            pygame.draw.line(s, BAT, (cx, cy - px(14)), (cx, cy + px(14)), px(2))

    def draw_hud(self):
        s = self.screen
        pygame.draw.rect(s, BLACK, (0, 0, W, px(64)))
        total = self.max_innings()
        inn = min(self.inning, total) if self.inning <= total else "EX"
        half = "T" if self.top else "B"
        lines = [
            (f"PRAC-{'BAT' if self.practice == 'bat' else 'PITCH'} "
             f"[{self.diff_name()}]  CPU {self.score[0]} - Player {self.score[1]}")
            if self.practice else
            f"{half}{inn}  CPU {self.score[0]} - Player {self.score[1]}",
            f"B:{self.balls} S:{self.strikes} O:{self.outs}",
            ("BAT: CPU (Player pitches)" if self.top else "BAT: Player (SPACE x2 to swing)"),
        ]
        x = px(12)
        for idx, ln in enumerate(lines):
            t = self.small.render(ln, True, WHITE)
            s.blit(t, (x, px(6) + idx * px(18)))
        # difficulty label top-right
        dt_ = self.small.render(self.diff_name(), True, YELLOW)
        s.blit(dt_, (W - dt_.get_width() - px(12), px(8)))
        ds = self.small.render(DIFF_SUB[self.difficulty], True, WHITE)
        s.blit(ds, (W - ds.get_width() - px(12), px(28)))
        if self.state not in ("title", "gameover", "rules"):
            qh = self.small.render("P: pause  Q: menu  F11: fullscreen", True, WHITE)
            s.blit(qh, (W - qh.get_width() - px(12), px(46)))
        # message bar
        pygame.draw.rect(s, BLACK, (0, H - px(56), W, px(56)))
        m = self.font.render(self.msg, True, YELLOW)
        s.blit(m, (px(14), H - px(50)))
        sub = self.small.render(self.sub, True, WHITE)
        s.blit(sub, (px(14), H - px(24)))
        # power meter
        if self.state == "pitch" and self.meter_active:
            pygame.draw.rect(s, BLACK, (W - px(240), H - px(150), px(200), px(22)))
            pygame.draw.rect(s, WHITE, (W - px(240), H - px(150), px(200), px(22)), px(2))
            w = int(px(200) * self.meter)
            pygame.draw.rect(s, METER_RED if self.meter > 0.8 else YELLOW, (W - px(238), H - px(148), w, px(18)))
            # zone ticks: zone edges readable without relying on hue
            for frac in (0.4, 0.8):
                tx = W - px(240) + int(px(200) * frac)
                pygame.draw.line(s, BLACK, (tx, H - px(150)), (tx, H - px(150) + px(22)), px(1))
            t = self.small.render("SPACE to lock power", True, WHITE)
            s.blit(t, (W - px(240), H - px(172)))
        # hit power meter — pitching style: SPACE starts it, SPACE again swings
        if self.state == "batwait":
            bx, by = W - px(250), H - px(130)
            pygame.draw.rect(s, BLACK, (bx, by, px(210), px(24)))
            pygame.draw.rect(s, WHITE, (bx, by, px(210), px(24)), px(2))
            w = int(px(206) * self.bat_power)
            col = METER_GREEN if self.bat_power > 0.8 else (YELLOW if self.bat_power > 0.4 else METER_RED)
            pygame.draw.rect(s, col, (bx + px(2), by + px(2), w, px(20)))
            for frac in (0.4, 0.8):
                tx = bx + int(px(210) * frac)
                pygame.draw.line(s, BLACK, (tx, by), (tx, by + px(24)), px(1))
            t = self.small.render("SPACE again = SWING!" if self.bat_charging else "SPACE = start meter", True, WHITE)
            s.blit(t, (bx - px(10), by - px(20)))

    def draw_rules(self):
        s = self.screen
        panel = pygame.Rect(px(100), px(75), px(700), px(480))
        pygame.draw.rect(s, (10, 10, 15), panel)
        pygame.draw.rect(s, WHITE, panel, px(3))
        title = self.rules_font.render("RULES OF BASEBALL", True, YELLOW)
        s.blit(title, (W // 2 - title.get_width() // 2, px(90)))
        ez, med, hard = (DIFF_PARAMS[k] for k in ("easy", "medium", "hard"))
        rows = [
            ("GOAL: ", "Outscore the CPU. The Player always bats first."),
            ("MODES: ", f"Regular Season = {ez['innings']} innings (Easy), pitches {ez['cpu_pitch'][0]}-{ez['cpu_pitch'][1]} px/s"),
            ("", f"Playoffs = {med['innings']} innings (Medium), pitches {med['cpu_pitch'][0]}-{med['cpu_pitch'][1]} px/s"),
            ("", f"World Series = {hard['innings']} innings (Hard), pitches {hard['cpu_pitch'][0]}-{hard['cpu_pitch'][1]} px/s"),
            ("BATTING: ", "SPACE starts the power meter, SPACE again locks it and swings."),
            ("", "Aim the cursor with the mouse; time the 2nd press. UP = fly, DOWN = grounder."),
            ("PITCHING: ", "Aim with the mouse, SPACE starts the meter, SPACE again throws."),
            ("", "Full power is fast but wild. 4 balls = walk, 3 strikes = strikeout."),
            ("FIELDING: ", "Move the circled fielder with ARROWS / WASD. Catch = out."),
            ("", "Misplay an easy catch and the runners take extra bases."),
            ("RUNNING: ", "Automatic. Singles, doubles, triples, homers and walks advance runners."),
            ("OUTS: ", "Strikeout, caught fly ball, or groundout. 3 outs ends the half-inning."),
            ("WIN: ", "Most runs after all innings wins. A tie means extra innings."),
            ("PRACTICE: ", "Endless batting or pitching — pick it on the menu."),
        ]
        y = px(140)
        for head, body in rows:
            if head:
                h = self.small.render(head, True, YELLOW)
                s.blit(h, (px(130), y))
                b = self.small.render(body, True, WHITE)
                s.blit(b, (px(130) + h.get_width(), y))
            else:
                b = self.small.render(body, True, WHITE)
                s.blit(b, (px(150), y))
            y += px(26)
        foot = self.small.render("H / Esc / SPACE: back to menu", True, YELLOW)
        s.blit(foot, (W // 2 - foot.get_width() // 2, px(520)))

    def start_game(self):
        self.practice = None
        self.top = False
        self.inning = 1
        self.paused = False
        self.new_batter()
        self.start_cpu_pitch()
        self.say(f"Player bats first! [{self.diff_name()}]",
                 "SPACE starts the meter, SPACE again swings.")

    def start_practice(self, kind):
        # endless batting or pitching: sides never flip, game never ends
        self.practice = kind
        self.top = False if kind == "bat" else True
        self.inning = 1
        self.paused = False
        self.new_batter()
        if kind == "bat":
            self.start_cpu_pitch()
            self.say(f"Batting practice [{self.diff_name()}]",
                     "SPACE x2: meter + swing. Q: menu when done.")
        else:
            self.state = "pitch"
            self.meter_active = False
            self.say(f"Pitching practice [{self.diff_name()}]",
                     "Mouse aim, SPACE x2 to pitch. Q: menu when done.")

    def quit_to_menu(self):
        # keep difficulty/menu selection, clear the current game
        paused_now = False
        self.reset()
        self.paused = paused_now

    def draw_title(self):
        panel = pygame.Rect(W // 2 - px(340), px(150), px(680), px(343))
        pygame.draw.rect(self.screen, (0, 0, 0), panel)
        pygame.draw.rect(self.screen, WHITE, panel, px(3))
        # shadow helper: black offset behind bright text
        def title_text(text, font, color, y):
            shadow = font.render(text, True, BLACK)
            fg = font.render(text, True, color)
            x = W // 2 - fg.get_width() // 2
            self.screen.blit(shadow, (x + px(3), y + px(3)))
            self.screen.blit(fg, (x, y))
        if self.menu_index < 3:
            sub_line = (f"Player (home) vs CPU - "
                        f"{DIFF_PARAMS[DIFFS[self.menu_index]]['innings']} innings")
        elif self.menu_index < 5:
            sub_line = f"Practice: {PRAC_LABEL[PRACS[self.menu_index - 3]]} - endless"
        title_text("ARCADE BASEBALL", self.title_font, YELLOW, px(160))
        title_text(sub_line, self.font, WHITE, px(228))
        title_text("Pitch: mouse + SPACE x2 | Bat: mouse + SPACE x2 | Field: arrows | P: pause Q: menu",
                   self.small, WHITE, px(258))
        # difficulty modes: Easy=Regular Season (3), Medium=Playoffs (5), Hard=World Series (9)
        box_w, box_h, gap, by = px(200), px(74), px(15), px(290)
        x0 = W // 2 - (box_w * 3 + gap * 2) // 2
        for i, key in enumerate(DIFFS):
            sel = (i == self.menu_index)
            bx = x0 + i * (box_w + gap)
            pygame.draw.rect(self.screen, YELLOW if sel else (60, 60, 75),
                             (bx, by, box_w, box_h))
            pygame.draw.rect(self.screen, WHITE, (bx, by, box_w, box_h), px(3) if sel else px(1))
            fg = BLACK if sel else WHITE
            num = self.small.render(f"{i + 1}. {DIFF_LABEL[key]}", True, fg)
            self.screen.blit(num, (bx + box_w // 2 - num.get_width() // 2, by + px(12)))
            sub = self.small.render(DIFF_SUB[key], True, fg)
            self.screen.blit(sub, (bx + box_w // 2 - sub.get_width() // 2, by + px(40)))
        # practice modes: endless batting or pitching
        pb_w, pb_h, pb_gap, pb_y = px(200), px(50), px(15), px(370)
        px0 = W // 2 - (pb_w * 2 + pb_gap) // 2
        for j, pkey in enumerate(PRACS):
            sel = (3 + j == self.menu_index)
            bx = px0 + j * (pb_w + pb_gap)
            pygame.draw.rect(self.screen, YELLOW if sel else (60, 60, 75),
                             (bx, pb_y, pb_w, pb_h))
            pygame.draw.rect(self.screen, WHITE, (bx, pb_y, pb_w, pb_h), px(3) if sel else px(1))
            fg = BLACK if sel else WHITE
            num = self.small.render(f"{4 + j}. {PRAC_LABEL[pkey]}", True, fg)
            self.screen.blit(num, (bx + pb_w // 2 - num.get_width() // 2, pb_y + px(8)))
            sub = self.small.render(PRAC_SUB[pkey], True, fg)
            self.screen.blit(sub, (bx + pb_w // 2 - sub.get_width() // 2, pb_y + px(26)))
        # flashing prompt for visibility
        if (pygame.time.get_ticks() // 500) % 2 == 0:
            title_text("LEFT/RIGHT + SPACE, or press 1-5", self.small, YELLOW, px(428))
        else:
            title_text("LEFT/RIGHT + SPACE, or press 1-5", self.small, WHITE, px(428))
        title_text("Press SPACE to start", self.font, WHITE, px(450))
        title_text("H: rules of baseball   -   F11: fullscreen", self.small, WHITE, px(471))

    def draw_pause(self):
        self.screen.blit(self._pause_dim, (0, 0))
        panel = pygame.Rect(W // 2 - px(220), H // 2 - px(70), px(440), px(140))
        pygame.draw.rect(self.screen, BLACK, panel)
        pygame.draw.rect(self.screen, WHITE, panel, px(3))
        t = self.big.render("PAUSED", True, YELLOW)
        self.screen.blit(t, (W // 2 - t.get_width() // 2, H // 2 - px(55)))
        s1 = self.small.render("P: resume   Q/Esc: quit to menu", True, WHITE)
        self.screen.blit(s1, (W // 2 - s1.get_width() // 2, H // 2 + px(10)))

    def draw_gameover(self):
        # End card styled like the main menu: black panel, white border,
        # shadowed title text so it reads over the field.
        won = self.score[1] > self.score[0]
        tied = self.score[0] == self.score[1]
        text = "Player WINS!" if won else ("TIE!" if tied else "CPU WINS")
        panel = pygame.Rect(W // 2 - px(340), H // 2 - px(140), px(680), px(280))
        pygame.draw.rect(self.screen, BLACK, panel)
        pygame.draw.rect(self.screen, WHITE, panel, px(3))

        def card_text(msg, font, color, y):
            shadow = font.render(msg, True, BLACK)
            fg = font.render(msg, True, color)
            x = W // 2 - fg.get_width() // 2
            self.screen.blit(shadow, (x + px(3), y + px(3)))
            self.screen.blit(fg, (x, y))

        card_text(text, self.title_font, YELLOW, H // 2 - px(125))
        card_text(f"Final: CPU {self.score[0]} - Player {self.score[1]}",
                  self.big, WHITE, H // 2 - px(45))
        card_text(f"Mode: {self.diff_name()} ({DIFF_SUB[self.difficulty]})",
                  self.font, YELLOW, H // 2 + px(20))
        if (pygame.time.get_ticks() // 500) % 2 == 0:
            card_text("SPACE / R to restart (same mode)", self.small, YELLOW,
                      H // 2 + px(70))
        else:
            card_text("SPACE / R to restart (same mode)", self.small, WHITE,
                      H // 2 + px(70))

    def run(self):
        while True:
            # cap dt so a hitch can't teleport the ball/runners
            dt = min(self.clock.tick(FPS) / 1000.0, 0.05)
            keys = pygame.key.get_pressed()
            for e in pygame.event.get():
                if e.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if e.type == pygame.MOUSEMOTION and not self.paused:
                    mx, my = self.to_logical(e.pos)
                    if self.state == "pitch":
                        self.aim = [max(px(150), min(W - px(150), mx)), max(px(80), min(H - px(60), my))]
                    elif self.state == "batwait":
                        self.bat_aim = [max(W // 2 - px(126), min(W // 2 + px(126), mx)),
                                        max(px(384), min(px(587), my))]
                if e.type == pygame.KEYDOWN and e.key in (pygame.K_F11, pygame.K_f) and not getattr(e, "repeat", False):
                    self.toggle_fullscreen()
                    continue
                if e.type == pygame.KEYDOWN and e.key == pygame.K_h and not getattr(e, "repeat", False):
                    if self.state == "title":
                        self.state = "rules"
                        continue
                    elif self.state == "rules":
                        self.state = "title"
                        continue
                if e.type == pygame.KEYDOWN and e.key in (pygame.K_ESCAPE, pygame.K_q):
                    if self.state == "rules":
                        self.state = "title"
                        continue
                    if self.state != "title":
                        self.quit_to_menu()
                        continue
                if e.type == pygame.KEYDOWN and e.key == pygame.K_p:
                    if self.state not in ("title", "gameover", "rules"):
                        self.paused = not self.paused
                        if self.paused:
                            self.bat_charging = False
                        continue
                if self.paused:
                    continue
                if e.type == pygame.KEYDOWN and e.key == pygame.K_SPACE:
                    if self.state == "title":
                        if self.menu_index < 3:
                            self.difficulty = DIFFS[self.menu_index]
                            self.start_game()
                        else:
                            self.start_practice(PRACS[self.menu_index - 3])
                    elif self.state == "rules":
                        self.state = "title"
                    elif self.state == "runners":
                        # skip animation
                        self.runners_t = 9999.0
                    elif self.state == "gameover":
                        self.reset()
                        self.start_game()
                    elif self.state == "pitch":
                        if not self.meter_active:
                            self.meter_active = True
                            self.meter = 0.0
                            self.meter_dir = 1
                        else:
                            self.meter_value = self.meter
                            self.meter_active = False
                            self.throw_player_pitch()
                    elif self.state == "batwait":
                        if not self.swing_done and not getattr(e, "repeat", False):
                            if not self.bat_charging:
                                # 1st press: start the power meter (like pitching)
                                self.bat_charging = True
                                self.bat_power = 0.0
                                self.bat_dir = 1
                            else:
                                # 2nd press: lock power AND swing at this moment
                                self.player_swing(power=self.bat_power)
                if e.type == pygame.KEYDOWN and e.key == pygame.K_r and self.state == "gameover":
                    self.reset()
                    self.start_game()
                if self.state == "title" and e.type == pygame.KEYDOWN:
                    if e.key == pygame.K_LEFT:
                        self.menu_index = (self.menu_index - 1) % 5
                        if self.menu_index < 3:
                            self.difficulty = DIFFS[self.menu_index]
                    elif e.key == pygame.K_RIGHT:
                        self.menu_index = (self.menu_index + 1) % 5
                        if self.menu_index < 3:
                            self.difficulty = DIFFS[self.menu_index]
                    elif e.key in (pygame.K_1, pygame.K_KP1):
                        self.menu_index, self.difficulty = 0, "easy"
                        self.start_game()
                    elif e.key in (pygame.K_2, pygame.K_KP2):
                        self.menu_index, self.difficulty = 1, "medium"
                        self.start_game()
                    elif e.key in (pygame.K_3, pygame.K_KP3):
                        self.menu_index, self.difficulty = 2, "hard"
                        self.start_game()
                    elif e.key in (pygame.K_4, pygame.K_KP4):
                        self.menu_index = 3
                        self.start_practice("bat")
                    elif e.key in (pygame.K_5, pygame.K_KP5):
                        self.menu_index = 4
                        self.start_practice("pitch")
            # per-frame updates (frozen while paused)
            if not self.paused:
                if self.bat_anim > 0:
                    self.bat_anim += dt
                    if self.bat_anim > 0.35:
                        self.bat_anim = 0.0
                if self.crowd_timer > 0:
                    self.crowd_timer -= dt
                    if self.crowd_timer <= 0:
                        self.crowd_celebrate = None
                if self.state == "pitch" and self.meter_active:
                    self.meter += self.meter_dir * dt * 1.6
                    if self.meter >= 1.0:
                        self.meter, self.meter_dir = 1.0, -1
                    if self.meter <= 0.0:
                        self.meter, self.meter_dir = 0.0, 1
                if self.state == "pitch_live":
                    self.update_player_pitch_live(dt)
                if self.state == "batwait":
                    self.update_cpu_pitch(dt)
                    if self.bat_charging and not self.swing_done:
                        self.bat_power += self.bat_dir * dt * 1.8
                        if self.bat_power >= 1.0:
                            self.bat_power, self.bat_dir = 1.0, -1
                        if self.bat_power <= 0.0:
                            self.bat_power, self.bat_dir = 0.0, 1
                if self.state == "hit":
                    self.update_hit(dt, keys)
                if self.state == "contact":
                    self.update_contact(dt)
                if self.state == "runners":
                    self.update_runners(dt)

            self.draw_field()
            self.draw_actors()
            self.draw_hud()
            if self.state == "title":
                self.draw_title()
            if self.state == "rules":
                self.draw_rules()
            if self.state == "gameover":
                self.draw_gameover()
            if self.paused and self.state not in ("title", "gameover"):
                self.draw_pause()
            self.present()


if __name__ == "__main__":
    Game().run()
