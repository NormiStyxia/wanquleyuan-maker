#!/usr/bin/env python3
"""Sokoban level verifier with ice mechanics and BFS solver."""

import sys
from collections import deque

def verify_solution(level, solution):
    """Verify a solution string for a Sokoban level with ice mechanics.
    Returns (success, message, step_details)."""
    w = level["width"]
    h = level["height"]
    wall_set = set(tuple(p) for p in level["walls"])
    ice_set = set(tuple(p) for p in level.get("ice", []))
    target_set = set(tuple(p) for p in level["targets"])

    px, py = level["player"]
    boxes = [list(b) for b in level["boxes"]]

    dir_map = {'U': (0, -1), 'D': (0, 1), 'L': (-1, 0), 'R': (1, 0)}
    details = []

    for step_idx, move in enumerate(solution):
        if move not in dir_map:
            return False, f"Step {step_idx+1}: invalid move '{move}'", details
        dx, dy = dir_map[move]
        nx, ny = px + dx, py + dy

        # Bounds check
        if nx < 0 or nx >= w or ny < 0 or ny >= h:
            return False, f"Step {step_idx+1} ({move}): player out of bounds ({nx},{ny})", details
        if (nx, ny) in wall_set:
            return False, f"Step {step_idx+1} ({move}): player hit wall ({nx},{ny})", details

        # Check if pushing a box
        box_idx = None
        for i, b in enumerate(boxes):
            if b[0] == nx and b[1] == ny:
                box_idx = i
                break

        pushed_box = False
        if box_idx is not None:
            # Calculate box destination
            bx, by = nx + dx, ny + dy
            if bx < 0 or bx >= w or by < 0 or by >= h:
                return False, f"Step {step_idx+1} ({move}): box push out of bounds ({bx},{by})", details
            if (bx, by) in wall_set:
                return False, f"Step {step_idx+1} ({move}): box push into wall ({bx},{by})", details
            for i, b in enumerate(boxes):
                if i != box_idx and b[0] == bx and b[1] == by:
                    return False, f"Step {step_idx+1} ({move}): box push into another box at ({bx},{by})", details

            boxes[box_idx] = [bx, by]
            pushed_box = True

            # Ice sliding for box
            if (bx, by) in ice_set:
                while (bx, by) in ice_set:
                    nbx, nby = bx + dx, by + dy
                    if nbx < 0 or nbx >= w or nby < 0 or nby >= h:
                        break
                    if (nbx, nby) in wall_set:
                        break
                    box_blocked = False
                    for i, b in enumerate(boxes):
                        if i != box_idx and b[0] == nbx and b[1] == nby:
                            box_blocked = True
                            break
                    if box_blocked:
                        break
                    bx, by = nbx, nby
                    boxes[box_idx] = [bx, by]

        # Move player
        px, py = nx, ny

        # Ice sliding for player
        if (px, py) in ice_set and not pushed_box:
            while (px, py) in ice_set:
                npx, npy = px + dx, py + dy
                if npx < 0 or npx >= w or npy < 0 or npy >= h:
                    break
                if (npx, npy) in wall_set:
                    break
                player_blocked = False
                for b in boxes:
                    if b[0] == npx and b[1] == npy:
                        player_blocked = True
                        break
                if player_blocked:
                    break
                px, py = npx, npy

        box_positions = [(b[0], b[1]) for b in boxes]
        detail = f"Step {step_idx+1} ({move}): player=({px},{py}) boxes={box_positions}"
        if pushed_box:
            detail += " [PUSH]"
        details.append(detail)

    # Check win condition
    for t in level["targets"]:
        t_tuple = tuple(t)
        found = False
        for b in boxes:
            if b[0] == t_tuple[0] and b[1] == t_tuple[1]:
                found = True
                break
        if not found:
            return False, f"Target {t_tuple} not covered. Final boxes: {[(b[0],b[1]) for b in boxes]}", details

    return True, f"SOLVED in {len(solution)} steps!", details


def print_board(level, player=None, boxes=None):
    """Print the board state."""
    w = level["width"]
    h = level["height"]
    wall_set = set(tuple(p) for p in level["walls"])
    ice_set = set(tuple(p) for p in level.get("ice", []))
    target_set = set(tuple(p) for p in level["targets"])

    if player is None:
        player = tuple(level["player"])
    if boxes is None:
        boxes = [tuple(b) for b in level["boxes"]]
    box_set = set(tuple(b) for b in boxes)

    for y in range(h):
        row = ""
        for x in range(w):
            pos = (x, y)
            if pos in wall_set:
                row += "#"
            elif pos == player:
                if pos in target_set:
                    row += "+"  # player on target
                elif pos in ice_set:
                    row += "P"  # player on ice (show as P)
                else:
                    row += "P"
            elif pos in box_set:
                if pos in target_set:
                    row += "*"  # box on target
                elif pos in ice_set:
                    row += "B"  # box on ice
                else:
                    row += "B"
            elif pos in target_set:
                if pos in ice_set:
                    row += "T"
                else:
                    row += "T"
            elif pos in ice_set:
                row += "~"
            else:
                row += "."
        print(f"  r{y}: {row}")


def bfs_solve(level, max_states=500000):
    """BFS solver for Sokoban with ice. Returns solution string or None."""
    w = level["width"]
    h = level["height"]
    wall_set = frozenset(tuple(p) for p in level["walls"])
    ice_set = frozenset(tuple(p) for p in level.get("ice", []))
    target_list = [tuple(t) for t in level["targets"]]
    target_set = frozenset(target_list)

    px, py = level["player"]
    initial_boxes = tuple(sorted(tuple(b) for b in level["boxes"]))

    dir_map = {'U': (0, -1), 'D': (0, 1), 'L': (-1, 0), 'R': (1, 0)}
    moves = ['U', 'D', 'L', 'R']

    # State: (player_x, player_y, boxes_tuple)
    initial_state = (px, py, initial_boxes)
    queue = deque()
    queue.append((initial_state, ""))
    visited = {initial_state}

    states_checked = 0

    while queue:
        state, path = queue.popleft()
        states_checked += 1

        if states_checked > max_states:
            return None, states_checked

        px, py, boxes = state

        # Check win
        if all(t in boxes for t in target_list):
            return path, states_checked

        for move_char in moves:
            dx, dy = dir_map[move_char]
            nx, ny = px + dx, py + dy

            # Bounds + wall check
            if nx < 0 or nx >= w or ny < 0 or ny >= h:
                continue
            if (nx, ny) in wall_set:
                continue

            box_list = list(boxes)
            new_px, new_py = nx, ny
            pushed_box = False

            # Check box push
            if (nx, ny) in boxes:
                box_idx = box_list.index((nx, ny))
                bx, by = nx + dx, ny + dy
                if bx < 0 or bx >= w or by < 0 or by >= h:
                    continue
                if (bx, by) in wall_set:
                    continue
                # Check other boxes
                other_boxes = set(boxes) - {(nx, ny)}
                if (bx, by) in other_boxes:
                    continue

                box_list[box_idx] = (bx, by)
                pushed_box = True

                # Ice sliding for box
                if (bx, by) in ice_set:
                    cur_other = set(box_list) - {(bx, by)}
                    while (bx, by) in ice_set:
                        nbx, nby = bx + dx, by + dy
                        if nbx < 0 or nbx >= w or nby < 0 or nby >= h:
                            break
                        if (nbx, nby) in wall_set:
                            break
                        if (nbx, nby) in cur_other:
                            break
                        bx, by = nbx, nby
                    box_list[box_idx] = (bx, by)

            # Ice sliding for player (only if didn't push a box)
            if not pushed_box and (new_px, new_py) in ice_set:
                while (new_px, new_py) in ice_set:
                    npx, npy = new_px + dx, new_py + dy
                    if npx < 0 or npx >= w or npy < 0 or npy >= h:
                        break
                    if (npx, npy) in wall_set:
                        break
                    if (npx, npy) in set(box_list):
                        break
                    new_px, new_py = npx, npy

            new_boxes = tuple(sorted(box_list))
            new_state = (new_px, new_py, new_boxes)

            if new_state not in visited:
                visited.add(new_state)
                queue.append((new_state, path + move_char))

    return None, states_checked


# ============================================================
# LEVEL DEFINITIONS
# ============================================================

def make_border_walls(w, h):
    """Generate border walls for a w x h grid."""
    walls = []
    for x in range(w):
        walls.append([x, 0])
        walls.append([x, h - 1])
    for y in range(1, h - 1):
        walls.append([0, y])
        walls.append([w - 1, y])
    return walls


def level_7():
    """U-shaped corridor, 2 boxes, 9x8"""
    w, h = 9, 8
    walls = make_border_walls(w, h)
    # Dividing wall at col 4, rows 1-3
    for y in range(1, 4):
        walls.append([4, y])
    return {
        "name": "U 形回廊",
        "width": w, "height": h,
        "player": [3, 5],
        "walls": walls,
        "boxes": [[2, 3], [6, 3]],
        "targets": [[1, 1], [7, 1]],
        "ice": [],
    }


def level_8():
    """Zigzag push, 2 boxes, 9x9"""
    w, h = 9, 9
    walls = make_border_walls(w, h)
    # Internal walls creating zigzag corridors
    # Horizontal wall row 2, cols 2-5
    for x in range(2, 6):
        walls.append([x, 2])
    # Horizontal wall row 4, cols 3-7
    for x in range(3, 8):
        walls.append([x, 4])
    # Horizontal wall row 6, cols 1-5
    for x in range(1, 6):
        walls.append([x, 6])
    return {
        "name": "之字推箱",
        "width": w, "height": h,
        "player": [1, 7],
        "walls": walls,
        "boxes": [[3, 3], [6, 5]],
        "targets": [[7, 1], [1, 5]],
        "ice": [],
    }


def level_9():
    """L-shaped rooms, 2 boxes, 10x8"""
    w, h = 10, 8
    walls = make_border_walls(w, h)
    # Central cross walls
    for x in range(3, 7):
        walls.append([x, 3])
    walls.append([5, 1])
    walls.append([5, 2])
    walls.append([5, 4])
    walls.append([5, 5])
    walls.append([3, 5])
    walls.append([3, 4])
    return {
        "name": "L 形迂回",
        "width": w, "height": h,
        "player": [1, 6],
        "walls": walls,
        "boxes": [[2, 2], [7, 5]],
        "targets": [[8, 1], [2, 5]],
        "ice": [],
    }


def level_10():
    """Ice bridge, 2 boxes, 11x7"""
    w, h = 11, 7
    walls = make_border_walls(w, h)
    # Upper wall with gap
    for x in [2, 3, 4, 6, 7, 8]:
        walls.append([x, 2])
    # Lower wall with gap
    for x in [2, 3, 4, 6, 7, 8]:
        walls.append([x, 4])
    # Ice in the middle row (row 3), from col 2-8
    ice = [[x, 3] for x in range(2, 9)]
    return {
        "name": "冰桥横渡",
        "width": w, "height": h,
        "player": [5, 5],
        "walls": walls,
        "boxes": [[3, 1], [7, 5]],
        "targets": [[7, 1], [3, 5]],
        "ice": ice,
    }


def level_11():
    """Ice field with islands, 2 boxes, 10x8"""
    w, h = 10, 8
    walls = make_border_walls(w, h)
    # Island walls in ice field
    walls.append([3, 3])
    walls.append([6, 3])
    walls.append([3, 5])
    walls.append([6, 5])
    # Walls creating channels
    walls.append([5, 2])
    walls.append([5, 6])
    # Ice everywhere except borders, islands, and certain safe tiles
    ice = []
    wall_set = set(tuple(w2) for w2 in walls)
    safe_tiles = {(1, 1), (8, 1), (1, 6), (8, 6), (4, 4)}  # non-ice spots
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if (x, y) not in wall_set and (x, y) not in safe_tiles:
                ice.append([x, y])
    return {
        "name": "冰原孤岛",
        "width": w, "height": h,
        "player": [1, 1],
        "walls": walls,
        "boxes": [[4, 1], [4, 6]],
        "targets": [[8, 1], [1, 6]],
        "ice": ice,
    }


def level_12():
    """Mixed ice and corridors, 2 boxes, 11x9"""
    w, h = 11, 9
    walls = make_border_walls(w, h)
    # Upper room walls
    for x in range(1, 5):
        walls.append([x, 3])
    walls.append([4, 1])
    walls.append([4, 2])
    # Lower room walls
    for x in range(6, 10):
        walls.append([x, 5])
    walls.append([6, 6])
    walls.append([6, 7])
    # Ice strip in corridor
    ice = []
    for x in range(5, 10):
        ice.append([x, 3])
    for x in range(1, 6):
        ice.append([x, 5])
    return {
        "name": "冰廊迷局",
        "width": w, "height": h,
        "player": [2, 2],
        "walls": walls,
        "boxes": [[2, 1], [8, 7]],
        "targets": [[8, 1], [2, 7]],
        "ice": ice,
    }


# ============================================================
# MAIN: Design, solve, verify
# ============================================================

def main():
    levels = [
        (7, level_7),
        (8, level_8),
        (9, level_9),
        (10, level_10),
        (11, level_11),
        (12, level_12),
    ]

    results = {}

    for num, level_func in levels:
        level = level_func()
        print(f"\n{'='*60}")
        print(f"LEVEL {num}: \"{level['name']}\" ({level['width']}x{level['height']})")
        print(f"Player: {level['player']}")
        print(f"Boxes: {level['boxes']}")
        print(f"Targets: {level['targets']}")
        print(f"Ice cells: {len(level.get('ice', []))}")
        print(f"{'='*60}")
        print_board(level)

        print(f"\nSolving Level {num} with BFS...")
        solution, states = bfs_solve(level, max_states=800000)

        if solution is not None:
            print(f"  Found solution: \"{solution}\" ({len(solution)} steps, {states} states checked)")
            # Verify
            ok, msg, details = verify_solution(level, solution)
            if ok:
                print(f"  Verification: PASS - {msg}")
            else:
                print(f"  Verification: FAIL - {msg}")
                for d in details[-5:]:
                    print(f"    {d}")
            results[num] = {"solution": solution, "steps": len(solution), "verified": ok}
        else:
            print(f"  No solution found within {states} states!")
            print(f"  Level may be unsolvable or too complex for BFS.")
            results[num] = {"solution": None, "steps": 0, "verified": False}

    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    for num in sorted(results.keys()):
        r = results[num]
        status = "OK" if r["verified"] else "FAIL"
        sol = r["solution"] if r["solution"] else "NONE"
        print(f"  Level {num}: [{status}] {r['steps']} steps - \"{sol}\"")


if __name__ == "__main__":
    main()
