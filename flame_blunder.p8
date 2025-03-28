pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- flame blunder: hot steps

-- sprite reference:
-- 1-3: player sprites (idle, jump, fall)
-- 19-21: fire animation sprites (shifted from 16-18)
-- 35-37: enemy sprites (shifted from 32-34)
-- map tiles:
-- 4-6: stone blocks (non-flammable)
-- 7-10: wooden blocks (flammable)
-- 11-13: metal blocks (non-flammable)
-- 14-15: water tiles
-- 16-17: explosive barrels
-- 18: goal/exit tile
-- 22-25: additional platform tiles (non-flammable)
-- 26-29: additional flammable tiles
-- 30-32: burnt/charred tiles

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
flammable_tiles = {7, 8, 9, 10, 26, 27, 28, 29}
non_flammable_tiles = {4, 5, 6, 11, 12, 13, 22, 23, 24, 25}
water_tiles = {14, 15}
explosive_tiles = {16, 17}
burnt_tiles = {30, 31, 32}
goal_tile = 18

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
  load_sprites()
  load_maps()
  init_level(level)
  music(0)
end

function load_sprites()
  -- player idle sprite (1) - Nintendo-style hero
  spr_data(1, "0077770000ffff000ffaaff00ffaafff0ff00ff00ff00ff00ff00ff007f00f70")
  -- player jump sprite (2) - dynamic jumping pose
  spr_data(2, "0077770000ffff000ffaaff00ffaafff0ff00ff00ff00ff000ffff0000ff000")
  -- player fall sprite (3) - falling pose
  spr_data(3, "0077770000ffff000ffaaff00ffaafff0ff00ff00ff00ff00ff00ff00f700f7")
  
  -- stone blocks (4-6) - detailed Nintendo-style blocks
  spr_data(4, "7777777778888887788888877888888778888887788888877888888777777777")
  spr_data(5, "7777777778555887785758877855587778575877785558777888888777777777")
  spr_data(6, "7777777778888887788876877887788778877887788768877888888777777777")
  
  -- wooden blocks (7-10) - wood texture like Super Mario Bros 3
  spr_data(7, "6666666664066046660666666606666664066046666666666666666664066046")
  spr_data(8, "6666666666666666606666666666606666666666666660666066666666666666")
  spr_data(9, "6460646066666666646064606666666664606460666666666460646066666666")
  spr_data(10, "6666666660646060666666666064606066666666606460606666666660646060")
  
  -- metal blocks (11-13) - shiny metal like Metroid
  spr_data(11, "999999999abbbba99abbbba99abbbba99abbbba99abbbba99abbbba9999999999")
  spr_data(12, "999999999aaaaa999a9a9a999aaaaa999a9a9a999aaaaa99999999999999999")
  spr_data(13, "999999999999999999bb88b999bb88b999bb88b999bb88b99999999999999999")
  
  -- water tiles (14-15) - animated water like Zelda
  spr_data(14, "00000000003bbb00033bbb3003bbbb3003bbbb300333bb300033330000000000")
  spr_data(15, "0000000000000000033bb3303bbbbbb333bbbb33333333330333333000000000")
  
  -- explosive barrels (16-17) - Donkey Kong-style barrels
  spr_data(16, "00888800088aa8808888888888888888888cc8888888cc8888888888088aa880")
  spr_data(17, "00888800088aa8808888cc888882cc8888888888888888888888888808aa8880")
  
  -- goal tile (18) - shiny Nintendo-style door
  spr_data(18, "00bbbb000bbbdbb0bbbddbbbbbbddbbbbdbddbbbbdbddbbbbbbdbbdb0bbbbbb0")
  
  -- fire animation sprites (19-21) - dynamic fire like Mario fireballs
  spr_data(19, "000800000089080008a8a80008a8a80000a8a000008a80000088800000080000")
  spr_data(20, "000800000089800008a9a80008aa880008aaa80000aaa0000088a00000080000")
  spr_data(21, "000800000089a00008aaa8000aaaa8000a8aa00008aa80000888800000880000")
  
  -- additional platform tiles (22-25) - more detailed platforms
  spr_data(22, "8888888878888887788888877888888778888887788888877888888788888888")
  spr_data(23, "99999999abbbbbba9abbbba99abbbba99abbbba99abbbba9abbbbbba99999999")
  spr_data(24, "6666666664666646646666466466664664666646646666466466664666666666")
  spr_data(25, "5555555556555655565556555655565556555655565556555655565555555555")
  
  -- additional flammable tiles (26-29) - Mario-style breakable blocks
  spr_data(26, "6466666664066666640666666406666664066666640666666406666666666466")
  spr_data(27, "6666666666666666666666666606606666066066666666666666666666666666")
  spr_data(28, "6666666660666606666666666066660666666666606666066666666660666606")
  spr_data(29, "6660666666606666666066666660666666606666666066666660666666606666")
  
  -- burnt tiles (30-32) - charred like after bomb explosions
  spr_data(30, "0000000000000000001100000011100000111000001110000001100000000000")
  spr_data(31, "0000000000111000001110000111100001111000111110001111100000000000")
  spr_data(32, "0001000000111000001110000111100001111000111110000111000000100000")
  
  -- enemy sprites (35-37) - Nintendo-style enemies
  spr_data(35, "0033330003bbbb303bbbbbb33bbbbbb303bbbb30003333000033330000033000") -- Goomba-like
  spr_data(36, "0022220002aaaa202aaaaaa22aaaaaa22a2222a2022222000022220000022000") -- Angry like Hammer Bro
  spr_data(37, "0099990009aaaa909aaaaaa99aaaaaa90a9999a0009999000099990000099000") -- Koopa-like
  
  -- set sprite flags (0=solid)
  for i=4,13 do
    fset(i, 0, true)  -- solid tile flag
  end
  
  -- set flags for additional platform tiles
  for i=22,25 do
    fset(i, 0, true)  -- solid tile flag
  end
end

function load_maps()
  -- level 1 (tutorial) - Super Mario Bros style intro level
  local lvl1 = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,7,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,26,0,0,0,0,0,7,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,7,7,7,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,18},
    {4,4,4,4,0,0,0,7,7,7,7,7,0,0,0,4},
    {5,5,5,5,0,0,0,0,0,0,0,0,0,4,4,5},
    {6,6,6,6,4,4,4,4,4,4,4,4,4,5,5,6}
  }
  
  -- level 2 (bridge) - Zelda-like bridge with obstacles
  local lvl2 = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,14,14,0,0,0,0,0,0},
    {0,0,0,0,0,0,7,14,14,14,0,0,0,0,0,0},
    {4,4,4,0,0,7,7,7,7,7,7,7,0,0,0,18},
    {5,5,5,0,0,0,0,0,0,0,0,0,0,4,4,4},
    {6,6,6,14,14,14,14,14,14,14,14,4,4,5,5,5},
    {6,6,6,14,14,14,14,14,14,14,14,5,5,6,6,6}
  }
  
  -- level 3 (explosive) - Bomberman/Zelda-style puzzle room
  local lvl3 = {
    {4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4},
    {5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5},
    {5,0,7,0,7,0,7,0,7,0,7,0,7,0,0,5},
    {5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5},
    {5,16,0,0,0,7,0,7,0,7,0,0,0,0,18,5},
    {5,5,4,4,4,4,4,4,4,4,4,4,4,4,4,5},
    {5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5},
    {5,0,0,0,7,0,0,0,0,0,0,7,0,0,0,5},
    {5,0,0,0,0,0,0,7,0,0,0,0,0,0,0,5},
    {5,0,0,0,0,8,8,8,8,8,8,0,0,0,0,5},
    {5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5},
    {5,0,0,0,0,7,0,0,16,0,0,7,0,0,0,5},
    {5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5},
    {5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5},
    {5,7,7,7,7,7,7,7,7,7,7,7,7,7,7,5},
    {5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5}
  }
  
  -- level 4 (temple) - Metroid/Zelda-like temple sanctuary
  local lvl4 = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,11,11,11,11,11,0,0,0,0,0,0,0},
    {0,0,0,11,11,0,0,0,11,11,0,0,0,0,0,0},
    {0,0,11,11,0,0,0,0,0,11,11,0,0,0,0,0},
    {0,0,11,0,0,7,0,7,0,0,11,0,0,0,0,0},
    {0,0,11,0,0,0,0,0,0,0,11,0,0,0,0,0},
    {0,0,11,0,0,0,18,0,0,0,11,0,0,0,0,0},
    {0,0,11,0,0,4,4,4,0,0,11,0,0,0,0,0},
    {4,4,4,7,7,5,5,5,7,7,4,4,4,0,0,0},
    {5,5,5,0,0,5,5,5,0,0,5,5,5,0,0,0},
    {5,5,5,0,0,6,6,6,0,0,5,5,5,4,4,4},
    {6,6,6,4,4,6,6,6,4,4,6,6,6,5,5,5}
  }
  
  -- set the maps
  set_map_data(0, 0, lvl1)
  set_map_data(0, 16, lvl2)
  set_map_data(0, 32, lvl3)
  set_map_data(0, 48, lvl4)
end

function spr_data(n, hex)
  -- convert hex string to sprite data and load it into sprite n-1
  local addr = (n-1) * 64
  for i=1,64 do
    local digit = sub(hex, i, i)
    local val = 0
    if digit == "0" then val = 0
    elseif digit == "1" then val = 1
    elseif digit == "2" then val = 2
    elseif digit == "3" then val = 3
    elseif digit == "4" then val = 4
    elseif digit == "5" then val = 5
    elseif digit == "6" then val = 6
    elseif digit == "7" then val = 7
    elseif digit == "8" then val = 8
    elseif digit == "9" then val = 9
    elseif digit == "a" then val = 10
    elseif digit == "b" then val = 11
    elseif digit == "c" then val = 12
    elseif digit == "d" then val = 13
    elseif digit == "e" then val = 14
    elseif digit == "f" then val = 15
    end
    poke(addr + i - 1, val)
  end
end

function set_map_data(x, y, map_data)
  -- set map data starting at position x,y
  for j=1,#map_data do
    for i=1,#map_data[j] do
      mset(x+i-1, y+j-1, map_data[j][i])
    end
  end
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
  -- no need to reload map data since it's already set
  -- in the load_maps function
  
  -- just make sure sprite flags are set correctly
  init_sprites()
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
end

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
  
  -- Nintendo-style title screen with logo
  -- Draw colorful logo background
  rectfill(20, 30, 108, 60, 2)
  rectfill(22, 32, 106, 58, 8)
  
  -- Title text
  print("flame blunder", 30, 40, 7)
  print("hot steps", 40, 48, 10)
  
  -- Nintendo-style frame
  rectfill(24, 70, 104, 110, 5)
  rectfill(26, 72, 102, 108, 0)
  
  print("your fire breath curse", 28, 75, 7)
  print("keeps causing problems!", 24, 83, 7)
  
  print("controls:", 40, 93, 10)
  print("arrows: move", 36, 100, 7)
  
  -- Blinking "Press start" text like Nintendo games
  if (time()*2) % 2 < 1 then
    print("press x/v to start", 30, 116, 10)
  end
  
  -- Animated fire at the corners
  local anim = flr(time() * 8) % 3
  spr(19 + anim, 16, 40)
  spr(19 + anim, 104, 40)
  spr(19 + anim, 16, 116)
  spr(19 + anim, 104, 116)
end

function draw_game()
  cls(0)
  
  -- draw map
  map(0, 0, 0, 0, 128, 64)
  
  -- draw enemies
  for e in all(enemies) do
    local sprite = 35
    if e.type == 2 then sprite = 36 end
    if e.type == 3 then sprite = 37 end
    
    spr(sprite, e.x, e.y, 1, 1, e.dx < 0)
  end
  
  -- draw player with Nintendo-style animation
  local sprite = p.spr_idle
  if not p.grounded then
    if p.dy < 0 then
      sprite = p.spr_jump  -- jump sprite
    else
      sprite = p.spr_fall  -- falling sprite
    end
  else
    -- walking animation when moving on ground (like Mario)
    if abs(p.dx) > 0.5 then
      -- alternate between sprites for walk cycle
      if (time()*8) % 2 < 1 then
        sprite = p.spr_idle
      else
        sprite = p.spr_fall  -- use fall sprite as walk frame
      end
    end
  end
  
  spr(sprite, p.x, p.y, 1, 1, p.flip)
  
  -- draw fire effect behind player when breathing fire
  if p.cool_down > 0 and not p.hold_breath then
    for i=1,2 do
      local fx = p.x + (p.flip and -4 or 8)
      local fy = p.y + 4 + rnd(2) - 1
      local anim = flr(time() * 16) % 3
      spr(19 + anim, fx, fy, 1, 1, p.flip)
    end
  end
  
  -- draw hold breath indicator (Mario-style power meter)
  if p.hold_breath then
    rectfill(p.x, p.y - 5, p.x + 8, p.y - 3, 1)
    pset(p.x + 4, p.y - 4, 12)
  end
  
  -- draw breath meter (like Zelda hearts)
  local meter_width = p.breath_meter/10
  rectfill(cam.x + 10, cam.y + 10, cam.x + 10 + meter_width, cam.y + 12, 8)
  rect(cam.x + 10, cam.y + 10, cam.x + 110, cam.y + 12, 7)
  
  -- draw fires
  for f in all(fires) do
    local anim = flr(time() * 8) % 3
    spr(19 + anim, f.x, f.y)
  end
  
  -- draw explosions
  for e in all(explosions) do
    circfill(e.x, e.y, e.r, e.c)
  end
  
  -- level indicator - Nintendo-style level display
  rectfill(cam.x + 2, cam.y + 2, cam.x + 40, cam.y + 9, 0)
  print("world " .. level, cam.x + 4, cam.y + 3, 7)
end

function draw_gameover()
  cls(0)
  
  -- Game Over text in Nintendo style
  for i=0,5 do
    print("game over!", 45+i, 50, 1)
    print("game over!", 45, 50+i, 1)
  end
  print("game over!", 45, 50, 8)
  
  print("you burned too much!", 30, 64, 7)
  
  -- Nintendo-style continue option
  if (time()*2) % 2 < 1 then
    print("press x/v to retry", 30, 90, 7)
  end
  
  -- Draw sad player
  spr(1, 60, 76)
end

function draw_win()
  cls(1) -- Blue background like Mario
  
  -- Nintendo-style victory screen
  -- Center frame
  rectfill(15, 30, 113, 110, 5)
  rectfill(17, 32, 111, 108, 0)
  
  -- Congratulations text with drop shadow
  print("you win!", 49, 40, 0)
  print("you win!", 48, 40, 10)
  
  print("you've found the legendary", 16, 55, 7)
  print("mouth guard artifact!", 25, 63, 7)
  print("no more fire troubles!", 25, 78, 11)
  
  -- Nintendo-style "Game Over" animation
  if (time()*2) % 2 < 1 then
    print("press x/v to play again", 18, 100, 10)
  end
  
  -- Draw trophy-like item
  spr(18, 56, 86)
  spr(18, 64, 86)
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
  for i=4,13 do
    fset(i, 0, true)
  end
  
  for i=22,25 do
    fset(i, 0, true)
  end
end

-- call sprite init on startup
init_sprites() 