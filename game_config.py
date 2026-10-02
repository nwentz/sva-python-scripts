"""Shared constants and tuning for Arcade Baseball.

Resolution: the game renders natively at W x H. S is the scale factor over
the original 900x650 layout; px() converts an original-layout pixel value to
the current canvas. To change resolution, set H (keeping aspect via BASE_W)
and every px()/W/H-relative measurement follows.
"""
import pygame

BASE_W, BASE_H = 900, 650
H = 1440  # native canvas height (1440p)
W = round(BASE_W * H / BASE_H)  # same aspect as the original layout
WIN_W, WIN_H = 997, 720  # default windowed size (canvas scales to any window)
FPS = 60
INNINGS = 3  # fallback only; real totals come from DIFF_PARAMS

S = H / BASE_H


def px(n):
    """Scale an original-layout pixel value to the current canvas."""
    return int(round(n * S))

def inning_title(inning, total, top):
    half = "Top" if top else "Bottom"
    return f"{half} {inning}/{total}"

WHITE = (240, 240, 240)
BLACK = (20, 20, 20)
GREEN_D = (34, 120, 60)
GREEN_L = (52, 150, 80)
BROWN = (170, 120, 70)
RED = (200, 50, 50)
BLUE = (50, 120, 220)
YELLOW = (250, 210, 80)
STAND_BG = (45, 45, 60)
METER_GREEN = (57, 255, 20)  # neon green: pops against both field greens
METER_RED = (213, 94, 0)  # vermillion: reads on black for protan viewers

HOME = (W // 2, H - px(120))
MOUND = (W // 2, H - px(340))
BASE1 = (W // 2 + px(170), H - px(290))
BASE2 = (W // 2, H - px(440))
BASE3 = (W // 2 - px(170), H - px(290))

STRIKE_ZONE = pygame.Rect(W // 2 - px(45), H - px(220), px(90), px(110))

DIFFS = ["easy", "medium", "hard"]
DIFF_LABEL = {"easy": "Regular Season", "medium": "Playoffs", "hard": "World Series"}
DIFF_SUB = {"easy": "Easy", "medium": "Medium", "hard": "Hard"}
DIFF_PARAMS = {
    "easy": {"cpu_pitch": (190, 280), "windup": (1.0, 1.4),
             "cpu_timing_sd": 0.12, "swing_in": 0.70, "swing_out": 0.22,
             "contact_bonus": -0.08, "cpu_field": 421, "player_field": 598,
             "zone_prob": 0.74, "perfect": 170, "foul": 340,
             "innings": 3},
    "medium": {"cpu_pitch": (354, 532), "windup": (0.7, 1.0),
               "cpu_timing_sd": 0.09, "swing_in": 0.75, "swing_out": 0.28,
               "contact_bonus": 0.0, "cpu_field": 454, "player_field": 576,
               "zone_prob": 0.62, "perfect": 133, "foul": 288,
               "innings": 5},
    "hard": {"cpu_pitch": (510, 731), "windup": (0.5, 0.8),
             "cpu_timing_sd": 0.06, "swing_in": 0.80, "swing_out": 0.34,
             "contact_bonus": 0.10, "cpu_field": 498, "player_field": 554,
             "zone_prob": 0.55, "perfect": 133, "foul": 288,
             "innings": 9},
}

PRACS = ["bat", "pitch"]
PRAC_LABEL = {"bat": "Batting Practice", "pitch": "Pitching Practice"}
PRAC_SUB = {"bat": "You bat", "pitch": "You pitch"}
