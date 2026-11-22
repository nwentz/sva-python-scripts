# Pizza Simulator - Quick Start Guide

## 🍕 Game Overview
A fast-paced pizza making simulation where you must fulfill customer orders by assembling, baking, and serving pizzas within a time limit.

## 🎮 Controls

| Action | Key |
|--------|-----|
| **Move Forward** | W |
| **Move Backward** | S |
| **Move Left** | A |
| **Move Right** | D |
| **Sprint** | SHIFT |
| **Look Around** | Mouse |
| **Interact / Grab** | G or Left Click |
| **Drop item / pizza** | L |
| **Knead the dough** | K (press 5 times) |
| **Spread the sauce** | L to start, then move the mouse in circles |
| **Cut the cheese** | L to start, then press C eight times |
| **Toggle Mouse / exit close-up** | ESC |

## 🕹️ Gameplay Loop

### Step 1: Start (DOUGH_STATION)
1. Look at DOUGH_STATION (left side)
2. Press **G** to pick up the dough
3. Move to the PREP_TABLE (center)
4. Press **L** to drop the dough ball onto the table - the camera zooms in on it
5. Press **K** five times to knead. The ball gets flatter and wider with every
   press until it is a full pizza base; the HUD shows the press counter.
   The normal camera returns automatically when the dough is ready.

> Walk right up to a counter before pressing **G** - every station is reachable,
> including the DOUGH station at the far left end of the row.

### Step 2: Sauce
1. Look at SAUCE_STATION and press **G** to grab the **sauce bottle**
2. Return to the PREP_TABLE
3. Press **L** at the prep table - the camera zooms in, then **move the mouse
   in a circle** over the dough to spread the sauce slowly (about four full turns).
   There is no E key for this.

### Step 3: Cheese
1. Look at CHEESE_STATION and press **G** to grab the cheese
2. Return to the PREP_TABLE
3. Press **L** at the prep table - the camera zooms in again
4. Press **C** eight times to cut the cheese. Short, thick yellow shreds are
   scattered over the sauce with each press.

### Step 4: Toppings
1. Look at TOPPING_STATION and press **G** to grab a topping
   (the station hands you whichever topping your current order still needs)
2. Return to the PREP_TABLE
3. Press **L** to drop the topping onto the cheese
4. Repeat until every topping count in the order is met. Each order picks a
   random mix; the station hands you a random type that is still short.

### Step 5: Bake (OVEN)
1. Press **G** at the PREP_TABLE to pick the pizza up
2. Carry it to the OVEN (top of room) and press **G** to put it in
3. Watch the baking timer! The oven glows and smokes, and the HUD counts it
   down ("OVEN: cooking... 6 s to pull it out")
4. Press **G** again at the oven when it says "Pizza is done!"

### Step 6: Serve (COUNTER)
1. Carry the baked pizza to the round **SERVE** table (right side) - a customer
   is waiting in the chair beside it
2. Press **G** to serve it - the customer takes the pizza and eats it, bite by
   bite, while the score is awarded
3. Get points!

> **Tip:** Dropped items fall with real physics, so aim at the pizza before
> pressing **L** to land the topping where you want it.

## 📊 Order System

Each order asks for **quantities** of toppings, not just types, and the exact
mix is **randomised for every pizza** (up to these maximums):
- **Pepperoni:** up to 6
- **Mushroom:** up to 3
- **Olive:** up to 2

The TOPPINGS station hands you a random kind that is still short, and the HUD
shows each type with its count. A missing or extra copy lowers the topping
score.

**Time limit:** 5 minutes (300 seconds) per order - enough time to knead the
dough and build the pizza without rushing.

## 🏆 Scoring

Score = (40% toppings match) + (40% baking quality) + (20% speed)

### Scoring Breakdown:
- **Toppings match:** 0-100%
  - Exact match: 100%
  - Partial match: 50%
  - No match: 0%
- **Baking quality:** 0-100%
  - Perfect bake: 100%
  - Slightly over/under: 80-90%
  - Burnt: 0%
- **Speed:** 0-100%
  - Fast service: 100%
  - Slow service: 50%

**Maximum score per pizza:** 100 points

## 🎯 Tips & Tricks

1. **Keep moving** - Don't waste time walking
2. **Learn the path** - Memorize station positions
3. **Watch the timer** - Time is your enemy!
4. **Perfect the bake** - Timing is everything
5. **Use SHIFT** - Sprint when moving between stations
6. **Read the HUD** - It shows order requirements and current status

## 🏠 Station Positions

```
                              (Left of the player, +X side)

┌─────────────┬──────────┬─────────────┬──────────────┬────────┐
│  DOUGH     │ SAUCE    │ CHEESE     │ TOPPINGS     │  OVEN  │
│ Station    │ Station  │ Station    │ Station      │ (Hot!) │
│ (6.3, 5)   │ (4.8, 5) | (3.3, 5)   │ (1.8, 5)     │ (0, 5) │
└─────────────┴──────────┴─────────────┴──────────────┴────────┘
     ┌─────────────┐
     │ PREP TABLE  │  In front of the row (2.55, 2)
     └─────────────┘
                                            ┌─────────┐
                                            │ COUNTER │  Right of the
                                            │ SERVE   │  player (-6.3, 3.6)
                                            └─────────┘
```

The whole cooking line runs along the `z = 5` counter and reads left to right
from the player's starting view: **DOUGH -> SAUCE -> CHEESE -> TOPPINGS ->
PREP TABLE -> OVEN -> SERVE**.

## 🎨 Visual Guide

- **Light color** = Ingredient type
  - Light cream = Dough
  - Reddish = Sauce
  - Yellow = Cheese
  - Dark red = Pepperoni
  - Grey = Prep table
  - Dark = Oven
  - Black = Counter

- **Pizza stages:**
  - Raw dough = pale ball, gets flatter and wider with each K press
  - Kneaded = large, flat base
  - Sauced = Red sauce visible
  - Cheesed = Cheese visible
  - Topped = Toppings added
  - Baking = Grows, glows
  - Baked = Perfect size, no glow
  - Burnt = Small, dark, smoking

## ⚠️ Common Mistakes

1. **Forgot to knead the dough** → Sauce is refused until 5 K presses
2. **Baked too early** → Undercooked (low score)
3. **Baked too late** → Burnt (0 points)
4. **Missing ingredients** → Order fails
5. **Wrong ingredient order** → Can't proceed

## 🆘 Getting Help

If you're stuck:
1. Check the HUD for hints
2. Look at station labels
3. Read on-screen feedback
4. Try the tutorial steps

Enjoy cooking! 🍕