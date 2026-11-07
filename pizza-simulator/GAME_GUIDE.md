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
| **Interact** | E or Left Click |
| **Toggle Mouse** | ESC |

## 🕹️ Gameplay Loop

### Step 1: Start (DOUGH_STATION)
1. Look at DOUGH_STATION (left side)
2. Press **E**
3. Hold pizza, move to PREP_TABLE (center)

### Step 2: Stretch
1. Stand at PREP_TABLE
2. Press **E** on the dough
3. Go grab ingredients from left stations

### Step 3: Assemble
1. **SAUCE_STATION** → Press **E** to grab sauce
2. **CHEESE_STATION** → Press **E** to grab cheese
3. **TOPPING_STATION** → Press **E** to grab pepperoni
4. Return to PREP_TABLE

### Step 4: Apply Ingredients
1. Press **E** at PREP_TABLE
2. Click on the dough to apply ingredients
3. Repeat for more toppings
4. Click on prep table again to lock ingredients

### Step 5: Bake (OVEN)
1. Go to OVEN (top of room)
2. Press **E** with pizza in hand
3. Watch the baking timer!
4. Wait for "Pizza is done" hint

### Step 6: Serve (COUNTER)
1. Go to SERVE COUNTER (far right)
2. Press **E** when pizza is done
3. Get points!

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
            │   OVEN  │  Top (0, 0.5, 5.2)
            │  (Hot!) │
            └─────────┘

┌─────────────┬──────────┬─────────────┬──────────────┬────────┐
│  DOUGH     │ SAUCE    │ CHEESE     │ TOPPINGS     │ PREP   │
│ Station    │ Station  │ Station    │ Station      │ Table  │
│ (-6, -5.2)  │ (-4.5,-5.2) │ (-3,-5.2)  │ (-1.5,-5.2)  │ (0,-5.2)│
└─────────────┴──────────┴─────────────┴──────────────┴────────┘
                           (Left wall)
                                           ┌─────────┐
                                           │ COUNTER │  Right (0, 0.5, 7.5)
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
