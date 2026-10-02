This is an AI-generated Python script baseball game made specifically for pygame. The user must first have pygame installed onto their computer. To install pygame, first make sure that you have python installed.

PYTHON INSTALL

Windows Users: Use Powershell with the command: winget install -e --id Python.Python.3.13

Mac Users: Use Terminal with the command: brew install python


Then to install pygame. Pip should already be pre-installed after your python install but if it isn't. Use this command:

PIP INSTALL

Windows Users: Use Powershell with the command: python3 -m ensurepip --default-pip

Mac Users: Use Terminal with the command: python3 -m ensurepip --upgrade


VENV INSTALL

Windows Users: Use Powershell with the command: py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1

Mac Users: Use Terminal with the command: python3 -m venv .venv
 source .venv/bin/activate

Now that you have Python and Pip installed, Use this command for either Windows or Mac: 

PYGAME INSTALL

pip install pygame


Test to make sure pygame is working by entering the command: python3 -m pygame.examples.aliens

This loads a pre-installed alien game. If you've got it, then you're set!


RUNNING ARCADE BASEBALL

 To run this game "Arcade Baseball", run this command in a terminal: py -3.13 baseball_game.py



Originally, I had started with a ball bounce game where the player bounces a ball and every bounce was a point added to the player's high score. I completely scrapped this idea in favor of a baseball game where the player plays baseball against a CPU. I integrated several aspects to make the game better/more fun to play. Multiple difficulty modes of easy, medium and hard, a rules menu, crowd cheering for homeruns and general runs, as well as a mode specifically for practicing pitching and batting separately freestyle. Compared to my original ball bounce game from class, this, in my opinion, is a way more enjoyable game for someone to play.

LIST OF DEFS

FIRST DEF: HANDWRITTEN, game_config.py, Lines 24-26

This is the def I wrote by hand in the game_config.py file. It defines the inning title, as in whether it is the top of the inning or the bottom of the inning. Top is the first half of the inning and Bottom is the second half of the inning. The code returns just that: which inning it is divided by the total innings left. Easy mode has 3 total innings, Medium mode has 5 total innings and Hard Mode has 9 total innings.

def inning_title(inning, total, top):
    half = "Top" if top else "Bottom"
    return f"{half} {inning}/{total}"


SECOND DEF: baseball_game.py, Lines 686-737

This def defines what happens when the player swings the bat and either hits the ball or misses it as well as the mechanics to how they do so. Whether the batter hits or misses the ball is dependent on the power put into the swing and if the mouse cursor is in line with the baseball for contact. There is also different varieties of missing a ball. The player can swing too early or too late plus their cursor could be away from the ball and lead to a foul. This can culminate into a strikeout. On the other hand, if they get a hit, they have made contact with the ball and from there, could get a single, double, triple, or homerun depending on how good their contact was.

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


THIRD DEF: baseball_game.py, Lines 950-984

This def defines the result of the hit itself, whether the Player or CPU batter flies out to any of the basemen and or fielders. Or advances to first, second, third base, or gets a homerun. This affects the position of the runners and the score of the game. Also defines the respective audience reactions, if a run is scored, then they celebrate a little. If a homerun is scored, they celebrate a lot. This goes for either Player or CPU.


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





YOUTUBE LINK FOR RECORDING:

https://youtu.be/8jieJkmuooQ