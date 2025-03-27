pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- flame blunder: hot steps

-- sprite reference:
-- 1-3: player sprites (idle, jump, fall)
-- 16-18: fire animation sprites
-- 32-34: enemy sprites (scared, angry, fire-immune)
-- map tiles:
-- 1-3: stone blocks (non-flammable)
-- 4-7: wooden blocks (flammable)
-- 8-10: metal blocks (non-flammable)
-- 11-12: water tiles
-- 13-14: explosive barrels
-- 15: goal/exit tile
-- 16-19: additional platform tiles (non-flammable)
-- 20-23: additional flammable tiles
-- 24-26: burnt/charred tiles
-- 27-28: additional water tiles
-- 29-30: additional explosive tiles

-- game states
gs_menu = 0
gs_game = 1
gs_over = 2
gs_win = 3

-- global variables
gamestate = gs_menu
level = 1
max_level = 4

-- player variables
p = {
  x = 16,
  y = 100,
  dx = 0,
  dy = 0,
  w = 8,
  h = 8,
  flip = false,
  grounded = false,
  was_grounded = false,
  jumped = false,
  hold_breath = false,
  breath_meter = 100,
  spr_idle = 1,
  spr_jump = 2,
  spr_fall = 3,
  hit_wall = false,
  cool_down = 0
}

-- fire variables
fires = {}
fire_timer = 0
fire_spread_time = 30

-- map variables
flammable_tiles = {4, 5, 6, 7, 20, 21, 22, 23}
non_flammable_tiles = {1, 2, 3, 8, 9, 10, 16, 17, 18, 19}
water_tiles = {11, 12, 27, 28}
explosive_tiles = {13, 14, 29, 30}
burnt_tiles = {24, 25, 26}
goal_tile = 15

-- camera
cam = {
  x = 0,
  y = 0
}

-- level start positions
level_start = {
  {x=16, y=100},  -- level 1
  {x=16, y=100},  -- level 2
  {x=16, y=16},   -- level 3
  {x=16, y=100}   -- level 4
}

-- enemy data
enemies = {}

-- explosions
explosions = {}

function _init()
  init_level(level)
  music(0)
end

function init_level(lvl)
  load_level(lvl)
  fires = {}
  explosions = {}
  enemies = init_enemies(lvl)
  p.x = level_start[lvl].x
  p.y = level_start[lvl].y
  p.dx = 0
  p.dy = 0
  p.jumped = false
  p.grounded = false
  p.cool_down = 0
  p.breath_meter = 100
  p.hold_breath = false
  fire_timer = 0
  cam.x = 0
  cam.y = 0
  gamestate = gs_game
end

function load_level(lvl)
  local mapx = 0
  local mapy = 0
  
  if lvl == 1 then
    -- tutorial level
    mapx, mapy = 0, 0
  elseif lvl == 2 then
    -- bridge level
    mapx, mapy = 0, 16
  elseif lvl == 3 then
    -- explosive level
    mapx, mapy = 0, 32
  elseif lvl == 4 then
    -- temple level
    mapx, mapy = 0, 48
  end
  
  reload(0x2000, 0x2000, 0x1000)
  memcpy(0x1000, 0x2000+mapx*128+mapy*8, 0x1000)
end

function init_enemies(lvl)
  local e = {}
  
  if lvl == 1 then
    -- no enemies in tutorial
  elseif lvl == 2 then
    add(e, {x=90, y=90, dx=0.5, type=1, w=8, h=8, scared=false})
  elseif lvl == 3 then
    add(e, {x=70, y=32, dx=0.5, type=2, w=8, h=8, angry=false})
  elseif lvl == 4 then
    add(e, {x=80, y=60, dx=0.5, type=3, w=8, h=8, fire_immune=true})
    add(e, {x=100, y=80, dx=0.5, type=1, w=8, h=8, scared=false})
  end
  
  return e
end

function _update()
  if gamestate == gs_menu then
    update_menu()
  elseif gamestate == gs_game then
    update_game()
  elseif gamestate == gs_over then
    update_gameover()
  elseif gamestate == gs_win then
    update_win()
  end
end

function update_menu()
  if btnp(5) then
    gamestate = gs_game
    sfx(0)
  end
end

function update_game()
  -- player controls
  update_player()
  
  -- fire spreading
  update_fires()
  
  -- enemy updates
  update_enemies()
  
  -- explosions
  update_explosions()
  
  -- check win condition
  check_goal()
  
  -- update camera
  update_camera()
end

function update_player()
  -- store previous state
  p.was_grounded = p.grounded
  p.hit_wall = false
  
  -- horizontal movement
  if btn(0) and not p.hold_breath then
    p.dx = max(p.dx - 0.5, -2)
    p.flip = true
  elseif btn(0) and p.hold_breath then
    p.dx = max(p.dx - 0.25, -1)
    p.flip = true
  elseif btn(1) and not p.hold_breath then
    p.dx = min(p.dx + 0.5, 2)
    p.flip = false
  elseif btn(1) and p.hold_breath then
    p.dx = min(p.dx + 0.25, 1)
    p.flip = false
  else
    p.dx *= 0.8
    if abs(p.dx) < 0.1 then p.dx = 0 end
  end
  
  -- hold breath
  if btn(5) and p.breath_meter > 0 then
    p.hold_breath = true
    p.breath_meter = max(0, p.breath_meter - 1)
  else
    p.hold_breath = false
    p.breath_meter = min(100, p.breath_meter + 0.5)
  end
  
  -- apply gravity
  p.dy += 0.3
  
  -- limit fall speed
  if p.dy > 3 then p.dy = 3 end
  
  -- horizontal collision
  local next_x = p.x + p.dx
  if solid(next_x, p.y) or solid(next_x, p.y + p.h - 1) or solid(next_x + p.w - 1, p.y) or solid(next_x + p.w - 1, p.y + p.h - 1) then
    p.hit_wall = true
    if abs(p.dx) > 1.5 then
      p.cool_down = 0
      create_fire(p.x, p.y)
      sfx(2)
    end
    p.dx = 0
  end
  
  -- jump
  if btnp(4) and p.grounded then
    p.dy = -4
    p.jumped = true
    if not p.hold_breath then
      create_fire(p.x, p.y)
      sfx(1)
    end
  end
  
  -- update position
  p.x += p.dx
  p.y += p.dy
  
  -- vertical collision
  p.grounded = false
  if p.dy > 0 then
    if solid(p.x, p.y + p.h) or solid(p.x + p.w - 1, p.y + p.h) then
      p.y = flr(p.y/8) * 8
      p.grounded = true
      p.jumped = false
      
      -- check if landing was hard
      if p.dy > 2 and not p.hold_breath and p.cool_down <= 0 then
        create_fire(p.x, p.y)
        sfx(2)
        p.cool_down = 20
      end
      
      p.dy = 0
    end
  elseif p.dy < 0 then
    if solid(p.x, p.y) or solid(p.x + p.w - 1, p.y) then
      p.y = flr(p.y/8) * 8 + 8
      p.dy = 0
    end
  end
  
  -- update cooldown
  if p.cool_down > 0 then
    p.cool_down -= 1
  end
  
  -- check if in water
  if in_water(p.x, p.y) then
    p.cool_down = 60
    sfx(3)
    for i=1,5 do
      add(explosions, {
        x = p.x + rnd(8),
        y = p.y + rnd(8),
        r = 2 + rnd(2),
        c = 12,
        life = 10 + rnd(10)
      })
    end
  end
  
  -- screen boundaries
  if p.x < 0 then p.x = 0 end
  if p.x > 127 - p.w then p.x = 127 - p.w end
  if p.y < 0 then p.y = 0 end
  if p.y > 127 - p.h then
    -- fell off level
    sfx(7)
    init_level(level)
  end
end

function create_fire(x, y)
  local fx = flr(x/8) * 8
  local fy = flr(y/8) * 8
  
  -- check if tile is flammable
  if is_flammable(fx/8, fy/8) and not fire_exists(fx, fy) then
    add(fires, {x=fx, y=fy, age=0, spread_timer=0})
  end
  
  -- create special effect
  for i=1,8 do
    add(explosions, {
      x = x + 4 + rnd(8) - 4,
      y = y + 4 + rnd(8) - 4,
      r = 2 + rnd(3),
      c = 8 + rnd(3),
      life = 5 + rnd(10)
    })
  end
end

function update_fires()
  fire_timer += 1
  
  for i=#fires,1,-1 do
    local f = fires[i]
    f.age += 1
    f.spread_timer += 1
    
    -- spread fire
    if f.spread_timer >= fire_spread_time then
      f.spread_timer = 0
      
      -- try to spread in all directions
      local spread_dirs = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}}
      for d in all(spread_dirs) do
        local nx = f.x + d[1] * 8
        local ny = f.y + d[2] * 8
        
        if is_flammable(nx/8, ny/8) and not fire_exists(nx, ny) and rnd() < 0.3 then
          add(fires, {x=nx, y=ny, age=0, spread_timer=0})
          sfx(4, -1, rnd(10), 1)
        end
      end
    end
    
    -- check if burning an explosive
    if is_explosive(f.x/8, f.y/8) then
      -- create explosion
      create_explosion(f.x, f.y, 16)
      mset(f.x/8, f.y/8, 0)  -- remove explosive
      sfx(5)
      del(fires, f)
    end
    
    -- check if fire should burn out
    if f.age > 400 then
      -- replace with burnt tile
      if is_flammable(f.x/8, f.y/8) then
        mset(f.x/8, f.y/8, burnt_tiles[1 + flr(rnd(#burnt_tiles))])
      end
      del(fires, f)
    end
  end
end

function create_explosion(x, y, size)
  -- check if player is nearby
  local dist = sqrt((p.x + 4 - x - 4)^2 + (p.y + 4 - y - 4)^2)
  if dist < size + 8 then
    p.dy = -4 * (size - dist) / size
    p.dx = sgn(p.x - x) * 3
    p.cool_down = 0
    create_fire(p.x, p.y)
  end
  
  -- create explosion particles
  for i=1,30 do
    add(explosions, {
      x = x + 4,
      y = y + 4,
      r = 2 + rnd(5),
      dx = rnd(2) - 1,
      dy = rnd(2) - 1,
      c = 8 + rnd(3),
      life = 10 + rnd(20)
    })
  end
  
  -- destroy nearby walls
  for i=-1,1 do
    for j=-1,1 do
      local tx = x/8 + i
      local ty = y/8 + j
      if is_flammable(tx, ty) or is_explosive(tx, ty) then
        if rnd() < 0.8 then
          mset(tx, ty, 0)
        else
          mset(tx, ty, burnt_tiles[1 + flr(rnd(#burnt_tiles))])
        end
      end
    end
  end
  
  -- create fires in nearby flammable tiles
  for i=-2,2 do
    for j=-2,2 do
      local tx = x/8 + i
      local ty = y/8 + j
      if is_flammable(tx, ty) and not fire_exists(tx*8, ty*8) and rnd() < 0.4 then
        add(fires, {x=tx*8, y=ty*8, age=0, spread_timer=0})
      end
    end
  end
}

function update_enemies()
  for e in all(enemies) do
    -- move enemies
    e.x += e.dx
    
    -- check for collisions with walls
    if solid(e.x, e.y + e.h) == false and solid(e.x + e.w - 1, e.y + e.h) == false then
      -- no ground beneath, turn around
      e.dx *= -1
    elseif solid(e.x + e.dx, e.y) or solid(e.x + e.dx, e.y + e.h - 1) then
      -- hit wall, turn around
      e.dx *= -1
    end
    
    -- check if close to fire
    local near_fire = false
    for f in all(fires) do
      local dist = sqrt((e.x + 4 - f.x - 4)^2 + (e.y + 4 - f.y - 4)^2)
      if dist < 24 then
        near_fire = true
        break
      end
    end
    
    -- enemy type behavior
    if e.type == 1 then
      -- scared enemy
      if near_fire and not e.scared then
        e.scared = true
        e.dx *= 2
        sfx(6)
      end
    elseif e.type == 2 then
      -- angry enemy
      if near_fire and not e.angry then
        e.angry = true
        e.dx = sgn(p.x - e.x) * 1.5
        sfx(6)
      end
    elseif e.type == 3 then
      -- fire immune enemy
      if near_fire then
        -- charge at player
        e.dx = sgn(p.x - e.x) * 1.2
      end
    end
    
    -- check player collision with enemy
    if collide(p, e) then
      -- player gets startled
      if p.cool_down <= 0 and not p.hold_breath then
        create_fire(p.x, p.y)
        sfx(2)
      end
      
      -- push player away
      p.dx = sgn(p.x - e.x) * 3
      p.dy = -2
      p.cool_down = 20
    end
  end
end

function update_explosions()
  for i=#explosions,1,-1 do
    local e = explosions[i]
    e.life -= 1
    
    if e.dx then
      e.x += e.dx
      e.y += e.dy
      e.dx *= 0.9
      e.dy *= 0.9
    end
    
    if e.life <= 0 then
      del(explosions, e)
    end
  end
end

function update_camera()
  -- follow player with slight delay
  local target_x = p.x - 64 + 4
  local target_y = p.y - 64 + 4
  
  cam.x += (target_x - cam.x) * 0.1
  cam.y += (target_y - cam.y) * 0.1
  
  -- keep camera in bounds
  cam.x = mid(0, cam.x, 128 - 128)
  cam.y = mid(0, cam.y, 128 - 128)
  
  -- apply camera
  camera(cam.x, cam.y)
end

function check_goal()
  -- check if player is on goal tile
  local tx = flr(p.x/8)
  local ty = flr(p.y/8)
  
  if mget(tx, ty) == goal_tile or mget(tx+1, ty) == goal_tile or
     mget(tx, ty+1) == goal_tile or mget(tx+1, ty+1) == goal_tile then
    sfx(8)
    level += 1
    
    if level > max_level then
      gamestate = gs_win
      music(2)
    else
      init_level(level)
    end
  end
end

function update_gameover()
  if btnp(5) then
    init_level(level)
  end
end

function update_win()
  if btnp(5) then
    level = 1
    init_level(level)
  end
end

function _draw()
  if gamestate == gs_menu then
    draw_menu()
  elseif gamestate == gs_game then
    draw_game()
  elseif gamestate == gs_over then
    draw_gameover()
  elseif gamestate == gs_win then
    draw_win()
  end
end

function draw_menu()
  cls(0)
  
  print("flame blunder: hot steps", 20, 40, 7)
  print("your fire breath curse", 28, 50, 6)
  print("keeps causing problems!", 24, 58, 6)
  
  print("controls:", 40, 75, 7)
  print("arrows: move", 36, 85, 6)
  print("z/c: jump (causes fire!)", 16, 93, 8)
  print("x/v: hold breath", 28, 101, 6)
  
  print("press x/v to start", 30, 116, 7 + (sin(time()) * 2))
end

function draw_game()
  cls(0)
  
  -- draw map
  map(0, 0, 0, 0, 128, 64)
  
  -- draw enemies
  for e in all(enemies) do
    local sprite = 32
    if e.type == 2 then sprite = 33 end
    if e.type == 3 then sprite = 34 end
    
    spr(sprite, e.x, e.y, 1, 1, e.dx < 0)
  end
  
  -- draw player
  local sprite = p.spr_idle
  if not p.grounded then
    if p.dy < 0 then
      sprite = p.spr_jump
    else
      sprite = p.spr_fall
    end
  end
  
  spr(sprite, p.x, p.y, 1, 1, p.flip)
  
  -- draw hold breath indicator
  if p.hold_breath then
    pset(p.x + 4, p.y - 2, 12)
  end
  
  -- draw breath meter
  rectfill(p.x, p.y - 4, p.x + p.breath_meter/10, p.y - 3, 12)
  
  -- draw fires
  for f in all(fires) do
    local anim = flr(time() * 8) % 3
    spr(16 + anim, f.x, f.y)
  end
  
  -- draw explosions
  for e in all(explosions) do
    circfill(e.x, e.y, e.r, e.c)
  end
  
  -- level indicator
  print("level " .. level, cam.x + 2, cam.y + 2, 7)
end

function draw_gameover()
  cls(0)
  print("game over!", 45, 50, 8)
  print("you burned too much!", 30, 64, 8)
  print("press x/v to retry", 30, 90, 7 + (sin(time()) * 2))
end

function draw_win()
  cls(0)
  print("you win!", 48, 40, 11)
  print("you've found the legendary", 15, 55, 7)
  print("mouth guard artifact!", 25, 63, 7)
  print("no more fire troubles!", 25, 78, 11)
  print("press x/v to play again", 18, 100, 7 + (sin(time()) * 2))
end

-- helper functions
function solid(x, y)
  local tx = flr(x/8)
  local ty = flr(y/8)
  
  local tile = mget(tx, ty)
  return fget(tile, 0)
end

function is_flammable(tx, ty)
  local tile = mget(tx, ty)
  return has_value(flammable_tiles, tile)
end

function is_explosive(tx, ty)
  local tile = mget(tx, ty)
  return has_value(explosive_tiles, tile)
end

function in_water(x, y)
  local tx = flr(x/8)
  local ty = flr(y/8)
  
  local tile = mget(tx, ty)
  return has_value(water_tiles, tile)
end

function fire_exists(x, y)
  for f in all(fires) do
    if f.x == x and f.y == y then
      return true
    end
  end
  return false
end

function has_value(t, val)
  for v in all(t) do
    if v == val then return true end
  end
  return false
end

function collide(a, b)
  return not (a.x > b.x + b.w or
             a.y > b.y + b.h or
             a.x + a.w < b.x or
             a.y + a.h < b.y)
end

-- initialize sprites
function init_sprites()
  -- set collision flags (0=solid)
  for i=1,10 do
    -- solid tiles
    fset(i, 0, true)
  end
  
  for i=16,19 do
    -- solid tiles
    fset(i, 0, true)
  end
end

-- call sprite init on startup
init_sprites() 