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
| **Jump** | SPACE |
| **Look Around** | Mouse |
| **Interact / Grab** | G or Left Click |
| **Drop topping on counter** | L |
| **Toggle Mouse** | ESC |

## 🕹️ Gameplay Loop

### Step 1: Start (DOUGH_STATION)
1. Look at DOUGH_STATION (left side)
2. Press **G** to pick up the dough
3. Move to the PREP_TABLE (center)
4. Press **L** to drop the dough onto the table - it falls into place

### Step 2: Sauce
1. Look at SAUCE_STATION and press **G** to grab the sauce
2. Return to the PREP_TABLE
3. Press **L** to drop the sauce onto the dough

### Step 3: Cheese
1. Look at CHEESE_STATION and press **G** to grab the cheese
2. Return to the PREP_TABLE
3. Press **L** to drop the cheese onto the sauce

### Step 4: Toppings
1. Look at TOPPING_STATION and press **G** to grab a topping
   (the station hands you whichever topping your current order still needs)
2. Return to the PREP_TABLE
3. Press **L** to drop the topping onto the cheese
4. Repeat for each topping your order requires

### Step 5: Bake (OVEN)
1. Press **G** at the PREP_TABLE to pick the pizza up
2. Carry it to the OVEN (top of room) and press **G** to put it in
3. Watch the baking timer!
4. Press **G** again at the oven when it says "Pizza is done!"

### Step 6: Serve (COUNTER)
1. Carry the baked pizza to the SERVE COUNTER (right side)
2. Press **G** to serve it
3. Get points!

> **Tip:** Dropped items fall with real physics, so aim at the pizza before
> pressing **L** to land the topping where you want it.

## 📊 Order System

Each order requires specific toppings:
- **Simple order:** 1 ingredient
- **Medium order:** 2 ingredients
- **Complex order:** 3 ingredients

**Time limit:** 60 seconds per order

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
            ┌─────────┐
            │   OVEN  │  Top (0, 0, 5)
            │  (Hot!) │
            └─────────┘

┌─────────────┬──────────┬─────────────┬──────────────┬────────┐
│  DOUGH     │ SAUCE    │ CHEESE     │ TOPPINGS     │ PREP   │
│ Station    │ Station  │ Station    │ Station      │ Table  │
│ (-6, -5.2)  │ (-4.5,-5.2) │ (-3,-5.2)  │ (-1.5,-5.2)  │ (0,-5.2)│
└─────────────┴──────────┴─────────────┴──────────────┴────────┘
                           (Left wall)
                                           ┌─────────┐
                                           │ COUNTER │  Right (6, 0, 5)
                                           │ SERVE   │
                                           └─────────┘
```

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
  - Raw dough = Small, pale
  - Stretched = Large, flat
  - Sauced = Red sauce visible
  - Cheesed = Cheese visible
  - Topped = Toppings added
  - Baking = Grows, glows
  - Baked = Perfect size, no glow
  - Burnt = Small, dark, smoking

## ⚠️ Common Mistakes

1. **Forgot to stretch dough** → Can't apply ingredients
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
