pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- game
debug=true
function ply_shoot()
 local bullet=nil
 if ply.form==1 then
  bullet=b_multi(
   v_cpy(ply.c_center),
   v_mul(ply.sh_dir,spd_bullet),
   t_player)
 else
  bullet=b_seeker(
   v_cpy(ply.c_center),
   v_cpy(ply.sh_dir),
   t_player,
   nil, -- use default lifetime
   ply.near_enemy,
   spd_seeker)
 end
 add(bullets,bullet)
 return bullet
end

function has_col(x,y)
 x,y=room.t.coord(x\8,y\8)
 return fget(mget(x,y),7)
end

function start_boss_enter1()
 room_state=r_boss_enter1
 room_state_timer=room_boss_fade_time
end

function start_boss_enter2()
 local boss=room.boss_func(vector(7,2))
 add(room.enemies,boss)
	ply.tile_frac.x=4
 ply.tile_frac.y=4
 ply.tile.x=7
 ply.tile.y=11
 room_state=r_boss_enter2
 room_state_timer=room_boss_fade_time
end

function goto_room(rx,ry,tcx,tcy,dir)
 room=floor[rx][ry]
 if room.boss then
  start_boss_enter1()
  return
 end
 local ix=tcx*16
 local iy=tcy*16
 local cx,cy,rx,ry=0,0,0,0
 if dir==d_up then
  -- end up at bottom of cell
  -- half in screen
  cx=7
  cy=14
  rx=0.5
 elseif dir==d_down then
  cx=7
  cy=2
  rx=0.5
 elseif dir==d_left then
  cx=14
  cy=7
  ry=0.5
 elseif dir==d_right then
  cx=2
  cy=7
  ry=0.5
 end
 ply.tile.x=ix+cx
 ply.tile.y=iy+cy
 ply.tile_frac.x=rx
 ply.tile_frac.y=ry
end

function goto_first_room_dir(dir)
 for _,l in ipairs(room.links) do
  local ppos=ply.pos
  if dir==d_up or dir==d_down then 
   if l.dir==dir and ppos.x>=l.door.x1-2 and ppos.x<=l.door.x2+2 then
    goto_room(l.trx,l.try,l.tcx,l.tcy,l.dir)
   end
  elseif l.dir==dir then
   if l.dir==dir and ppos.y>=l.door.y2-2 and ppos.y<=l.door.y1+2 then
    goto_room(l.trx,l.try,l.tcx,l.tcy,l.dir)
   end
  end
 end
end

function dmg_ply(n)
 if n==0 or ply.iframes>0 then return end
 ply.health-=n or 1
 -- 2 seconds of iframes
 ply.iframes=120
end

function present_lvlup()
 menu_idx=1
 show_lvlup_menu=true
 lvlup_choices={
  next_upgrade(),
  next_upgrade()
 }
end

function entity(c_rad,
                c_off,
                c_size,
                s_x,s_y,
                s_size,
                s_lut,
                s_hori_lut,
                s_vert_lut)
 -- entities have:
 --  velocity
 --  collision info
 --  drawing info
 local ent={
  -- top left position
  pos=vec(0,0),
  -- subpixel pos
  subpos=vec(0,0),
  -- velocity
  vel=vec(0,0),
  
  -- collision
  -- 
  c_active=true,
  -- bullet collision radius
  c_rad=c_rad or 1,
  -- aabb's offset from pos
  c_off=c_off or vec(0,0),
  -- aabb's size
  c_size=c_size or vec(0,0),
  
  -- drawing/sprites
  -- 
  -- spr sheet pos
  s_x=s_x or 0,
  s_y=s_y or 0,
  -- dir-to-spr lut
  s_dir_idx=4, -- start looking down
  s_lut=s_lut or {},
  -- dir-to-flip-luts
  s_hori_lut=s_hori_lut or {},
  s_vert_lut=s_vert_lut or {},
  -- spr size, also used for
  -- map collision
  s_size=s_size or vec(8,8),
 }
 
 -- optional:
 -- s_dir_idx - directional index from 1 to 8
 -- s_lut - dir-to-spr lut, overrides s_x,s_y
 
 -- aabb/rect overlap test
 ent.aabb=function(other)
	 local a1,a2=ent.c_p1,ent.c_p2
	 local b1,b2=other.c_p1,other.c_p2
	 return a1.x<b2.x and a2.x>b1.x and
	  a1.y<b2.y and a2.y>b1.y
	end
	
	-- circle overlap test
	ent.circ=function(o)
	 local min_d=ent.c_rad+o.c_rad
	 local d=v_dstsq(ent.c_center,o.c_center)
	 return ent.near(o) and d<(min_d*min_d)
	end
	
	ent.near=function(o,d)
	 d=d or 127
	 return abs(o.pos.x-ent.pos.x)<=d and
	  abs(o.pos.y-ent.pos.y)<=d
	end
 
 ent.upd_coords=function()
  ent.c_p1=v_add(ent.pos,ent.c_off)
  ent.c_p2=v_add(ent.c_p1,ent.c_size)
  ent.c_center=v_lerp(ent.c_p1,ent.c_p2,0.5)
  ent.s_center=v_add(ent.pos,v_div(ent.s_size,2))
 end
 
 ent.upd_spr=function()
  local s=ent.s_lut[ent.s_dir_idx]
  if s==nil then
	  ent.use_sx=ent.s_x
	  ent.use_sy=ent.s_y
	  return
  end
  ent.use_sx=8*(s%16)
  ent.use_sy=8*(s\16)
  ent.flip_x=ent.s_hori_lut[ent.s_dir_idx]
  ent.flip_y=ent.s_vert_lut[ent.s_dir_idx]
 end

 ent.move=function()
	 ent.subpos=v_add(ent.subpos,ent.vel)
	 
	 local left=ent.pos.x+ent.c_off.x
	 local right=left+ent.c_size.x
	 local top=ent.pos.y+ent.c_off.y
	 local bottom=top+ent.c_size.y
	 
	 -- horizontal
	 local col_left,col_right=false,false
	 while ent.subpos.x>1 do
	  if ent.c_active and has_col(right+1,ent.c_center.y) then
	   ent.subpos.x%=1
	   ent.vel.x=0
	   col_right=true
	  else
		  ent.subpos.x-=1
		  ent.pos.x+=1
		 end
	 end
	 while ent.subpos.x<-1 do
	  if ent.c_active and has_col(left-1,ent.c_center.y) then
	   ent.subpos.x%=1
	   ent.vel.x=0
	   col_left=true
	  else
		  ent.subpos.x+=1
		  ent.pos.x-=1
		 end
	 end
	 
	 -- vertical
	 local col_up,col_down=false,false
	 while ent.subpos.y>1 do
	  if ent.c_active and has_col(ent.c_center.x,bottom+1) then
	   ent.subpos.y%=1
	   ent.vel.y=0
	   col_down=true
	  else
		  ent.subpos.y-=1
		  ent.pos.y+=1
		 end
	 end
	 while ent.subpos.y<-1 do
	  if ent.c_active and has_col(ent.c_center.x,top-1) then
	   ent.subpos.y%=1
	   ent.vel.y=0
	   col_up=true
	  else
		  ent.subpos.y+=1
		  ent.pos.y-=1
		 end
	 end
	end
 
 ent.draw=function()
  sspr(
   ent.use_sx,ent.use_sy,
   ent.s_size.x,ent.s_size.y,
   ent.pos.x,ent.pos.y,
   ent.s_size.x,ent.s_size.y,
   ent.flip_x,ent.flip_y)
  if debug then
   -- draw top left, bottom right
   pset(ent.pos.x,ent.pos.y,11)
   pset(
   	ent.pos.x+ent.s_size.x,
   	ent.pos.y+ent.s_size.y,
   	11)
   -- draw aabb
   rect(
    ent.c_p1.x,ent.c_p1.y,
    ent.c_p2.x,ent.c_p2.y,
    12)
   -- draw radius
   circ(ent.c_center.x,ent.c_center.y,ent.c_rad)
  end
 end
 
 return ent
end

function _init()
 poke(0x5f2d,0x1)
 palt(6, true)
 palt(0, false)
 
 -- used for anti-cobblestoning
 last_keys_bits=0
 -- used for btnp non-repeat
 last_keys=0
 
 -- menu stuff
 menu_idx=1
 menu_noquit_counter=0
 
 show_lvlup_menu=false
 
 -- player stuff
 ply=entity(
  1,
  vec(3,3),
  vec(8,10),
  0,0,
  vec(16,16),
  -- s_lut
  {11,11,13,9,11,11,11,11},
  -- s_hori_lut
  {false,true,false,false,false,true,true},
  -- s_vert_lut
  {})
 ply.pos=vec(7*8,7*8)
 ply.health=3
 ply.iframes=0
 ply.near_enemy=nil
 ply.form=1
 ply.trans=false
 ply.trans_timer=0
 ply.spd=75/60 -- px/sec
 ply_spd_shoot_mult=0.85
 shoot_time=15 -- frame delay
 shoot_timer=0
 
 bullets={}
 spr_bullet=3
 spd_bullet=140/60 -- px/sec
 spd_seeker=1
 
 ply_dmg=2
 trans_quad_time=0
 trans_quad_timer=0
 trans_delay=20
 trans_self_dmg=0
 
 cell_x=3
 cell_y=3
 
 cam_x=64
 cam_y=64
 
 dungeon={
  rnd(floor_plans),
  rnd(floor_plans),
 }
 floor_idx=1
 
 r_normal=1
 r_boss_enter1=2
 r_boss_enter2=3
 room_state=r_normal
 room_state_timer=0
 room_boss_fade_time=60
 
 local plan=dungeon[floor_idx]
 floor=floor_from_plan(plan)
 room=floor[cell_x][cell_y]
 --add(room.enemies,e_walker(vec(20,20)))
 --add(room.enemies,e_jumper(vec(20,20)))
 --add(room.enemies,e_heavy(vec(20,20)))
 
 ply.upd_coords()
 --room.enemies[1].upd_coords()
 
 -- todo: do we really want
 --  to present this on startup?
 present_lvlup()
end

-->8
-- update
function _update60()
 if room_state==r_normal then
  update_normal()
 elseif room_state==r_boss_enter1 then
  if room_state_timer>0 then
   room_state_timer-=1
   if room_state_timer==0 then
    start_boss_enter2()
   end
  end
 elseif room_state==r_boss_enter2 then
  if room_state_timer>0 then
   room_state_timer-=1
   if room_state_timer==0 then
    room_state=r_normal
   end
  end
 end
end

function update_normal()
 if ply.health <=0 then
  update_dead()
  return
 end
 
 if show_lvlup_menu then
  update_lvlup_menu()
  return
 end
 
 if trans_quad_timer>0 then
  trans_quad_timer-=1
 end

 if ply.trans then
  -- todo: spawn trans
  --  particles or something
  -- for an animation/effect
  ply.trans=false
  ply.trans_timer=1
 end

 if ply.trans_timer>0 then
  ply.trans_timer-=1
  if ply.trans_timer==0 then
   ply.form=ply.form==1and 2or 1
   trans_quad_timer=trans_quad_time
   dmg_ply(trans_self_dmg)
  end
 end

 -- grab btn_lut-mapped input
 -- keys() is wasd
 -- btn() is ⬅️➡️⬆️⬇️
 local keys_value=keys()
 local key_bits=btn_lut[keys_value&0b1111]
 local btn_bits=btn_lut[btn()&0b1111]
 ply.sh_dir=vec(dx_lut[btn_bits],dy_lut[btn_bits])
 ply.shoot=ply.sh_dir.x!=0 or ply.sh_dir.y!=0

 local use_spd=ply.spd
 if ply.shoot then
  use_spd*=ply_spd_shoot_mult
 end
 
 -- shift triggers transform
 ply.trans=(last_keys&0b10000!=0b10000) and keys_value&0b10000==0b10000
 if ply.trans then
  ply.trans_timer=trans_delay
  -- dont shoot when transforming
  ply.shoot=false
  -- dont move when transforming
  use_spd=0
 end
 
 if ply.trans_timer>0 then
  -- dont shoot when transforming
  ply.shoot=false
  -- dont move when transforming
  use_spd=0
 end
 
 -- updating player spd from
 -- player input direction
 ply.vel=vector(
  dx_lut[key_bits]*use_spd,
  dy_lut[key_bits]*use_spd)
 
 if key_bits>0 then
  ply.s_dir_idx=key_bits
 end
 
 if ply.shoot then
  ply.s_dir_idx=btn_bits
 end
 
 update_nearest_enemy()
 update_shoot() 
 update_bullets()
 update_enemies()
 
 if ply.iframes>0 then
  ply.iframes-=1
 end
 
 -- updating player pos from vel
 cleft,cright,cup,cdown=ply:move()
 
 -- test if player touching doors
 if not room.boss then
	 if cleft then
	  goto_first_room_dir(d_left)
	 elseif cright then
	  goto_first_room_dir(d_right)
	 elseif cup then
	  goto_first_room_dir(d_up)
	 elseif cdown then
	  goto_first_room_dir(d_down)
	 end
 end
 
 -- anti-cobble if diagonal
 if key_bits!=last_keys_bits and key_bits>4 then
  ply.subpos=v_add(v_flr(ply.subpos),v_half)
 end
 
 ply.upd_coords()
 ply.upd_spr()
 -- todo: do i need to update
 --  coords post-move or
 --  pre-move or both?

 -- get and clamp camera scroll
 cam_x,cam_y=v_unpck(ply.pos)
 clamp_scroll_to_room()
 
 last_keys_bits=key_bits
 last_keys=keys_value
end

function update_dead()
 if btnp(➡️) or btnp(⬅️) then
  menu_idx=menu_idx==1 and 2 or 1
 end
 
 if menu_noquit_counter>0 then
  menu_noquit_counter-=1
 end
 
 if btnp(🅾️) and menu_idx==2 then
  menu_noquit_counter=150
 end
 
 if btnp(🅾️) and menu_idx==1 then
  _init()
 end
end

function update_lvlup_menu()
 if btnp(⬆️) or btnp(⬇️) then
  menu_idx=menu_idx==1 and 2 or 1
 end
 
 if btnp(🅾️) then
  lvlup_choices[menu_idx].exec()
  show_lvlup_menu=false
 end
end

function update_nearest_enemy()
 local min_dist=32767
 ply.near_enemy=nil
 for e in all(room.enemies) do
  local d=v_dstsq(ply.pos, e.pos)
  if d<min_dist then
   min_dist=d
   ply.near_enemy=e
  end
 end
end

function update_ply_spr(key_bits,btn_bits)
 if not v_eq(ply.velocity,v_zero) then
  -- set state for player sprite
  ply.spr=ply_spr_lut[key_bits]
  ply.flip_y=ply_vert_lut[key_bits]
  ply.flip_x=ply_hori_lut[key_bits]
 end
 
 if ply.shoot then
  -- shooting overrides the
  -- player's sprite & flip
  ply.spr=ply_spr_lut[btn_bits]
  ply.flip_y=ply_vert_lut[btn_bits]
  ply.flip_x=ply_hori_lut[btn_bits]
 end
end

function update_shoot()
	if shoot_timer>0 then
  shoot_timer-=1
 elseif ply.shoot then
  local b=ply_shoot()
  shoot_timer=shoot_time*b.rate_mult
 end
end

function update_bullets()
 for i=#bullets,1,-1 do
  local bul=bullets[i]
  bul.upd_coords()
  bul.upd_spr()
  local bx,by=v_unpck(bul.s_center)
  if bx<0 or
    bx>256 or
    by<0 or
    by>256 then
   -- too far away, remove
   deli(bullets,i)
  else
   -- update bullets & handle
   -- collisions with player &
   -- other entities
   if not bul:update() then
    deli(bullets,i)
   elseif bul.team==t_player then
    for ei=#room.enemies,1,-1 do
     local e=room.enemies[ei]
     if bul.circ(e) then
	     local dmg=ply_dmg*bul.dmg_mult
      if trans_quad_timer>0 then
       dmg*=4
      end
      if not e.dmg(dmg) then
       deli(room.enemies,ei)
      end
      deli(bullets,i)
     end
    end
   elseif bul.circ(ply) then
    dmg_ply()
    deli(bullets,i)
   end
  end
 end
end

function update_enemies()
 for i=#room.enemies,1,-1 do
  local e=room.enemies[i]
  e.upd_coords()
  e.upd_spr()
  e.update()
 end
end
-->8
-- draw
function _draw()
 if room_state==r_normal then
  draw_normal()
 elseif room_state==r_boss_enter1 then
  poke(0x5f34, 0x2)
  local pcenter=center(ply)
  local r=128*(room_state_timer-1)/room_boss_fade_time
  circfill(pcenter.x,pcenter.y,r,0x1800)
  poke(0x5f34, 0x0)
  circ(pcenter.x,pcenter.y,r,7)
 elseif room_state==r_boss_enter2 then
  cls()
  draw_boss_room()
  draw_enemies()
  ply:draw()
  draw_ply_hp()
  poke(0x5f34, 0x2)
  local pcenter=center(ply)
  local r=128*(room_boss_fade_time-room_state_timer)/room_boss_fade_time
  circfill(pcenter.x,pcenter.y,r,0x1800)
  poke(0x5f34, 0x0)
  circ(pcenter.x,pcenter.y,r,7)
 end
end

function draw_normal()
 cls(0)
 if ply.health<=0 then
  draw_dead_menu()
  return
 end

 camera(cam_x-64, cam_y-64)
 if room.boss then
  draw_boss_room()
 else
  room.t.draw()
  draw_doors()
 end
 if (ply.iframes%10)<7 then
  ply:draw()
 end
 draw_bullets()
 draw_enemies()
 
 camera(0,0)
 draw_ply_hp()
 
 if show_lvlup_menu then
  draw_lvlup_menu()
 end
 
 -- debug/test zone
end

function draw_boss_room()
 map(1,1,1,1,13,13)
 rect(0,0,127,127,7)
end

function draw_bullets()
 for b in all(bullets) do
  b.draw()
 end
end

function draw_enemies()
 for e in all(room.enemies) do
  e.draw()
 end
end

function draw_doors()
 for l in all(room.links) do
  spr(l.door.spr1,l.door.x1,l.door.y1,1,1,l.door.flip_x,l.door.flip_y)
  spr(l.door.spr1+1,l.door.x2,l.door.y2,1,1,l.door.flip_x,l.door.flip_y)
 end
end

function draw_ply_hp()
 for i=0,ply.health-1 do
  spr(4,1+i*9,1)
 end
end

function draw_lvlup_menu()
 rect(6,30,124,90,7)
 rectfill(7,31,123,89,0)
 
 local c1=lvlup_choices[1]
 local c2=lvlup_choices[2]
 
 for i,v in ipairs(c1.desc) do
  print(v,10,28+i*6,7)
 end
 
 for i,v in ipairs(c2.desc) do
  print(v,10,58+i*6,7)
 end
 
 if menu_idx==1 then
  rect(8,32,120,34+#c1.desc*6,7)
 else
  rect(8,62,120,64+#c2.desc*6,7)
 end
end

function draw_dead_menu()
 print("YOU ARE DEAD,", 38, 40, 7)
 print("NOT BIG SURPRISE", 32, 46, 7)
 
 -- centered on thirds 43, 85
 print("start", 33, 82)
 print("again", 33, 88)
 print("quit", 92, 85)
 
 if menu_idx==1 then
  print("🅾️", 33-9, 85)
 else
  print("🅾️", 92-9, 85)
 end
 
 if menu_noquit_counter>0 then
  print("you cant go...", 38, 64)
 end
end
-->8
-- input util
unit_45=0.707
btn_lut={[0]=0,1,2,0,3,5,6,3,4,8,7,4,0,1,2,0}
dx_lut={[0]=0,-1,1,0,0,-0.707,0.707,0.707,-0.707}
dy_lut={[0]=0,0,0,-1,1,-0.707,-0.707,0.707,0.707}

-- remapping keyboards
function keys()
 -- l r u d
 return (tonum(stat(28, 4)))|
        (tonum(stat(28, 7))<<1)|
        (tonum(stat(28,26))<<2)|
        (tonum(stat(28,22))<<3)|
        (tonum(stat(28,225))<<4)|
        (tonum(stat(28,44))<<5)
end

-->8
-- room types
function room_square()
 map(0, 0)
end

function coord_square(x,y)
 return x,y
end

function room_long()
 map(0, 16, 0, 0, 32, 16)
end

function coord_long(x,y)
 return x,y+16
end

function room_tall()
 map(32, 0, 0, 0, 16, 32)
end

function coord_tall(x,y)
 return x+32,y
end

-- north-east corner l-room
function room_corner_ne()
 -- open-right cell
 map(0, 16, 0, 0, 16, 16)
 -- ne-corner cell
 map(48, 0, 128, 0, 16, 16)
 -- open-up cell
 map(32, 16, 128, 128, 16, 16)
end

function coord_corner_ne(x,y)
 if y<16 then
  if x<16 then return x,y+16 end
  return x+32,y+0
 end
 return x+16,y+0
end

-- north-west corner l-room
function room_corner_nw()
 -- open-left cell
 map(16, 16, 128, 0, 16, 16)
 -- nw-corner cell
 map(16, 0, 0, 0, 16, 16)
 -- open-up cell
 map(32, 16, 0, 128, 16, 16)
end

function coord_corner_nw(x,y)
 if x<16 then
  -- nw corner cell
  if y<16 then return x+16,y end
  -- open up cell
  return x+32,y
 end
 -- open left
 return x,y+16
end

-- south-east corner l-room
function room_corner_se()
 -- open-right cell
 map(0, 16, 0, 128, 16, 16)
 -- se-corner cell
 map(48, 16, 128, 128, 16, 16)
 -- open-down cell
 map(32, 0, 128, 0, 16, 16)
end

function coord_corner_se(x,y)
 if y>16 then
  -- open-right cell
  if x<16 then return x,y end
  -- se corner cell
  return x+32,y
 end
 -- open-down cell
 return x+16,y
end

-- south-west corner l-room
function room_corner_sw()
 -- open-left cell
 map(16, 16, 128, 128, 16, 16)
 -- sw-corner cell
 map(64, 0, 0, 128, 16, 16)
 -- open-down cell
 map(32, 0, 0, 0, 16, 16)
end

-- maps cx,cy to the correct
-- tile coords, in corner_sw
-- n.b. necessary w/ compacted
-- map, for correct mget calls
function coord_corner_sw(x,y)
 if x<16 then
  -- top left (open-down) cell
  if y<16 then return x+32,y end
  -- sw corner cell
  return x+64,y-16
 end
 -- bot right (open-left) cell
 return x,y
end

room_types={
 square={
  w=1,h=1,
  draw=room_square,
  coord=coord_square,
 },
 tall={
  w=1,h=2,
  draw=room_tall,
  coord=coord_tall,
 },
 long={
  w=2,h=1,
  draw=room_long,
  coord=coord_long,
 },
 corner_ne={
  w=2,h=2,
  draw=room_corner_ne,
  coord=coord_corner_ne,
 },
 corner_se={
  w=2,h=2,
  draw=room_corner_se,
  coord=coord_corner_se,
 },
 corner_nw={
  w=2,h=2,
  draw=room_corner_nw,
  coord=coord_corner_nw,
 },
 corner_sw={
  w=2,h=2,
  draw=room_corner_sw,
  coord=coord_corner_sw,
 }
}

-->8
-- ent & vectors util

function dot(x1,y1,x2,y2)
 return x1*x2+y1*y2
end

function sqrlen(x,y)
 return x*x+y*y
end

function sqrdist(x1,y1,x2,y2)
 return sqrlen(x2-x1,y2-y1)
end

function check_vdst(a,b,d)
 d=d or 127
 return abs(a.x-b.x)<=d and abs(a.y-b.y)<=d
end

function check_dist(x1,y1,x2,y2,a)
 -- 179 is the smallest amount we
 -- can square (e.g. in a sqrdist check)
 -- before overflowing in p8
 a=a or 127
 return abs(x2-x1)<=a and abs(y2-y1)<=a
end

function ent_rect(ent)
 local a1=v_add(topleft(ent),vector(ent.ox,ent.oy))
 local a2=v_add(a1,vector(ent.w,ent.h))
 return a1,a2
end

function aabb(a,b)
 local a1,a2=a.c_p1,a.c_p2
 local b1,b2=b.c_p1,b.c_p2
 return a1.x<b2.x and a2.x>b1.x and
  a1.y<b2.y and a2.y>b1.y
end

function topleft(ent)
 local v=vector(
  ent.tile.x*8+ent.tile_frac.x,
  ent.tile.y*8+ent.tile_frac.y)
 if ent.spr_off then
  v=v_add(v,ent.spr_off)
 end
 return v
end

function center(ent)
 return v_add(topleft(ent),vector(ent.spr_size.x/2,ent.spr_size.y/2))
end

function clamp_scroll_to_room()
 -- clamp camera to room
 local right=room.t.w*128-64
 local bottom=room.t.h*128-64

 -- left is always 64
 if cam_x<64 then
  cam_x=64
 end
 if cam_x>right then
  cam_x=right
 end
 -- top is always 64
 if cam_y<64 then
  cam_y=64
 end
 if cam_y>bottom then
  cam_y=bottom
 end
end
-->8
-- bullet funcs
t_player=0
t_enemy=1

b_lut={1,2,0,2,1,2,0,2,1}
b_hori_lut={true,true,false,false,false,false,false,true,true}
b_vert_lut={false,false,false,false,false,true,true,true,false}

function bullet(pos,
                vel,
                c_rad,
                c_size,
                s_pos,
                s_size,
                team,
                lifetime,
                s_lut)
 -- c_off and c_size are used
 -- to calcualte the center
 local b=entity(
  c_rad,
  v_zero,
  c_size,
  s_pos.x,s_pos.y,
  s_size,
  s_lut or b_lut,
  b_hori_lut,
  b_vert_lut)
 b.c_active=false
 b.pos=v_sub(v_add(v_flr(pos),v_half),vec(3.5,3.5))
 b.vel=vel
 b.team=team
 b.lifetime=lifetime
 b.rate_mult=1
 b.dmg_mult=1
 
 b.update=function()
  b.move()
  return true
 end

 b.upd_spr=function()
	 local angle=v_ang(b.vel)
	 angle+=0.0625 -- [0.0625,1.0625)
	 angle=flr(angle*8)+1 -- [1,9]

	 local s=b.s_lut[angle]
	 if s==nil then
	  b.use_sx=ent.s_x
	  b.use_sy=ent.s_y
	  return
	 end
	 
	 local sx,sy=8*(s%16),8*(s\16)
	 b.use_sx=b.s_x+sx
	 b.use_sy=b.s_y+sy
	 b.flip_x=b.s_hori_lut[angle]
	 b.flip_y=b.s_vert_lut[angle]
 end
 
 return b
end

function b_linear(pos,vel,team,lifetime)
 local b=bullet(
  pos,
  vel,
  2,
  vec(8,8),
  vec(0,24),
  vec(8,8),
  team,
  lifetime)

 return b
end

function b_multi(pos,vel,team,lifetime)
 local b=bullet(
  pos,
  vel,
  3,
  vec(7,7),
  vec(24,0),
  vec(7,7),
  team,
  lifetime)

 b.multi_ang=0
 b.multi_rot_spd=1/120
 b.multi_radius=3
 b.multi_cnt=3
 b.buls={}
 
 b.update=function()
	 if #b.buls!=b.multi_cnt then
	  b.buls={}
	  for i=1,b.multi_cnt do
	  	add(b.buls, {sprpos=v_cpy(v_zero),pos=v_cpy(v_zero)})
	  end
	 end
	 for i,bul in ipairs(b.buls) do
	  local frac=i/b.multi_cnt
	  -- bul center (used for collision)
	  bul.center.x=b.pos.x+cos(self.multi_ang+frac)*b.multi_radius
	  bul.center.y=b.pos.y+sin(self.multi_ang+frac)*b.multi_radius
	  -- bul sprite pos
	  bul.sprpos=v_sub(bul.center,v_div(b.spr_size, 2))
	 end
	 b.multi_ang+=b.multi_rot_spd
  b.move()
  return true
 end
 
 b.circ=function(o)
	 for _,bul in ipairs(b.buls) do
	  local min_d=b.c_rad+o.c_rad
	  if o.near(bul) then
		  local d=v_dstsq(bul.pos,o.c_center)
		  local rad=b.c_rad+o.c_rad
		  if d<rad*rad then
		   return true
		  end
		 end
	 end
	 return false
 end
 
 b.draw=function()
  for bul in all(b.buls) do
   sspr(
	   ent.use_sx,ent.use_sy,
	   ent.s_size.x,ent.s_size.y,
	   bul.pos.x,bul.pos.y,
	   ent.s_size.x,ent.s_size.y)
	  if debug then
	   -- draw top left, bottom right
	   pset(bul.pos.x,bul.pos.y,11)
	   pset(
	   	bul.pos.x+b.s_size.x,
	   	bul.pos.y+b.s_size.y,
	   	11)
	   -- draw radius
	   circ(bul.pos.x,bul.pos.y,b.c_rad)
	  end
  end
 end

 return b
end

function b_multi_draw(self)
 for _,bul in ipairs(self.buls) do
  sspr(
   self.sx,self.sy,
   self.spr_size.x,self.spr_size.y,
   bul.sprpos.x,bul.sprpos.y,
   self.spr_size.x,self.spr_size.y)
  pset(bul.center.x,bul.center.y,9)
  circ(bul.center.x,bul.center.y,self.radius,8)
 end
end

function b_seeker(pos,dir,team,lifetime,target,spd)
 local b=bullet(
  pos,
  v_cpy(v_zero),
  2,
  vec(8,8),
  vec(0,16),
  vec(8,8),
  team,
  lifetime)
 
 -- overriding base values
 b.rate_mult=4
 b.dmg_mult=4
 
 -- seeker stuff
 b.nofollow_dist=7.5
 b.turn_spd=0.01
 b.dir=dir
 b.target=target
 b.spd=spd
 
 b.update=function()
	 if b.target then
	  -- target dir vector
	  local tdir=v_dir(b.c_center,b.target.c_center)
	  local dstsqr=v_dstsq(b.c_center,b.target.c_center)
	  
	  -- disable following/seeking
	  -- once its too close to the
	  -- target
	  if dstsqr<b.nofollow_dist*b.nofollow_dist then
	   b.target=nil
	  end
	  
	  local perp=v_perp(b.dir)
	  local d=v_dot(perp,tdir)
	  if d<0 then
	   b.dir=v_rot(b.dir,-b.turn_spd)
	  elseif d>0 then
	   b.dir=v_rot(b.dir,b.turn_spd)
	  end
	  
	  perp=v_cpy(b.dir)
	  local new_d=v_dot(perp,tdir)
	  
	  -- can this be replaced with sgn(d) != sgn(new_d)?
	  --if d>0 and new_d<0 or d<0 and new_d>0 then
	  if sgn(d) != sgn(new_d) then
	   b.dir=v_norm(tdir)
	  end
	 end
	
	 b.vel=v_mul(b.dir,b.spd)
  b.move()
	 return true
 end
 
 return b
end

function b_collides(self, ent)
 -- we do an n-scale dist
 -- check before the real
 -- radius-check. p8 uses
 -- a fixed cap of like 32k
 -- so its pretty easy to
 -- cause an overflow when
 -- checking large distances
 local bcenter=center(self)
 local ecenter=center(ent)
 if check_vdst(bcenter,ecenter) then
  local dist=v_dstsq(bcenter,ecenter)
  local min_rad=self.radius+ent.radius
  return dist<min_rad*min_rad
 end
 return false
end

function b_move(self)
 if self.life_time>0 then
  self.life_time-=1
  if self.life_time==0 then
   return false
  end
 end
 self.tile_frac=v_add(self.tile_frac,self.velocity)
 --
 -- horizontal
 while self.tile_frac.x>8 do
  self.tile_frac.x-=8
  self.tile.x+=1
 end
 while self.tile_frac.x<0 do
  self.tile_frac.x+=8
  self.tile.x-=1
 end
 
 --
 -- vertical
 while self.tile_frac.y>8 do
  self.tile_frac.y-=8
  self.tile.y+=1
 end
 while self.tile_frac.y<0 do
  self.tile_frac.y+=8
  self.tile.y-=1
 end
 return true
end

function b_draw(self)
 local angle=v_ang(self.velocity)
 angle+=0.0625 -- [0.0625,1.0625)
 angle=flr(angle*8) -- [0,8]
 local bspr=self.base_spr
 local lut=bul_spr_lut[angle+1]
 if not self.use_spr_lut then
  lut={0,false,false}
 end
 local bpos=topleft(self)
 spr(
  bspr+lut[1],
  bpos.x, bpos.y,
  1, 1,
  lut[2], lut[3])
 local bx,by=v_unpck(center(self))
 pset(bx,by,9)
 circ(bx,by,self.radius,8)
end
-->8
-- floor plan presets

-- generating floor plans at
-- runtime can be difficult to
-- do well, so... we can just
-- make some, and hope there
-- is enough variety with our
-- presets

-- floor plans are 5x5 grids
-- cells must have:
--  room type
--  room links
--   the position of the door
--   coords the door links to

d_up=0
d_down=1
d_left=2
d_right=3

fp_1_12={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_down,trx=1,try=3,tcx=0,tcy=0,},
 },
}
fp_1_32={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_right,trx=4,try=2,tcx=0,tcy=0,},
 },
}
fp_1_42={
 t=room_types.corner_nw,
 links={
   {dcx=0,dcy=0,dir=d_left,trx=3,try=2,tcx=0,tcy=0,},
   {dcx=0,dcy=1,dir=d_down,trx=4,try=4,tcx=0,tcy=0,},
   {dcx=0,dcy=1,dir=d_left,trx=3,try=3,tcx=0,tcy=0,},
 },
}
fp_1_13={
 t=room_types.long,
 links={
   {dcx=0,dcy=0,dir=d_down,trx=1,try=4,tcx=0,tcy=0,},
   {dcx=0,dcy=0,dir=d_up,trx=1,try=2,tcx=0,tcy=0,},
   {dcx=1,dcy=0,dir=d_right,trx=3,try=3,tcx=0,tcy=0,},
 },
}
fp_1_33={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_left,trx=1,try=3,tcx=1,tcy=0,},
   {dcx=0,dcy=0,dir=d_right,trx=4,try=2,tcx=0,tcy=1,},
 },
}
fp_1_14={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_up,trx=1,try=3,tcx=0,tcy=0,},
   {dcx=0,dcy=0,dir=d_down,trx=1,try=5,tcx=0,tcy=0,},
 },
}
fp_1_44={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_up,trx=4,try=2,tcx=0,tcy=1,},
 },
}
fp_1_15={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_up,trx=1,try=4,tcx=0,tcy=0,},
 },
}
fp_1={
 {{},fp_1_12,fp_1_13,fp_1_14,fp_1_15,},
 {{},{},{},{},{},},
 {{},fp_1_32,fp_1_33,{},{},},
 {{},fp_1_42,{},fp_1_44,{},},
 {{},{},{},{},{},},
}



fp_2_21={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_down,trx=2,try=2,tcx=0,tcy=0,},
   {dcx=0,dcy=0,dir=d_right,trx=3,try=1,tcx=0,tcy=0,},
 },
}
fp_2_31={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_left,trx=2,try=1,tcx=0,tcy=0,},
 },
}
fp_2_22={
 t=room_types.tall,
 links={
   {dcx=0,dcy=0,dir=d_up,trx=2,try=1,tcx=0,tcy=0,},
   {dcx=0,dcy=1,dir=d_right,trx=3,try=3,tcx=0,tcy=0,},
 },
}
fp_2_33={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_left,trx=2,try=2,tcx=0,tcy=1,},
   {dcx=0,dcy=0,dir=d_down,trx=3,try=4,tcx=0,tcy=0,},
 },
}
fp_2_34={
 t=room_types.long,
 links={
   {dcx=0,dcy=0,dir=d_down,trx=3,try=5,tcx=0,tcy=0,},
   {dcx=0,dcy=0,dir=d_up,trx=3,try=3,tcx=0,tcy=0,},
   {dcx=1,dcy=0,dir=d_right,trx=5,try=4,tcx=0,tcy=0,},
 },
}
fp_2_54={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_left,trx=3,try=4,tcx=1,tcy=0,},
 },
}
fp_2_35={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_up,trx=3,try=4,tcx=0,tcy=0,},
 },
}
fp_2={
 {{},{},{},{},{},},
 {fp_2_21,fp_2_22,{},{},{},},
 {fp_2_31,{},fp_2_33,fp_2_34,fp_2_35,},
 {{},{},{},{},{},},
 {{},{},{},fp_2_54,{},},
}


fp_3_32={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_down,trx=3,try=3,tcx=0,tcy=0,},
 },
}
fp_3_33={
 t=room_types.square,
 links={
   {dcx=0,dcy=0,dir=d_up,trx=3,try=2,tcx=0,tcy=0,},
 },
}
fp_3={
 {{},{},{},{},{},},
 {{},{},{},{},{},},
 {{},fp_3_32,fp_3_33,{},{},},
 {{},{},{},{},{},},
 {{},{},{},{},{},},
}


floor_plans={
 --fp_1,
 --fp_2,
 fp_3,
}

function precalc_doors()
 for _,plan in ipairs(floor_plans) do
 for _,col in ipairs(plan) do
 for _,cell in ipairs(col) do
 for _,link in ipairs(cell.links) do
  local door={
   x1=0,y1=0,
   x2=0,y2=0,
   spr1=19,
   flip_x=false,
   flip_y=false,
  }
  link.door=door
  if link.dir==d_up then
   door.x1=56
   door.x2=64
  elseif link.dir==d_down then
   door.x1=56
   door.x2=64
   door.y1=120
   door.y2=120
   door.flip_y=true
  elseif link.dir==d_left then
   door.y1=64
   door.y2=56
   door.spr1=21
  elseif link.dir==d_right then
   door.y1=64
   door.y2=56
   door.x1=120
   door.x2=120
   door.spr1=21
   door.flip_x=true
  end
  
  local ix=link.dcx*128
  local iy=link.dcy*128
  door.x1+=ix
  door.y1+=iy
  door.x2+=ix
  door.y2+=iy
 end
 end
 end
 end
end

precalc_doors()

function floor_from_plan(plan)
 local ends={}
 local floor={}
 for x,col in ipairs(plan) do
  local col_rooms={}
  for y,cell in ipairs(col) do
   local room={
    t=cell.t,
    links=cell.links,
    enemies={},
   }
   -- only add dead end room
   -- if its not the center room
   if cell.links and #cell.links==1 and not (x==3 and y==3) then
    add(ends,room)
   end
   add(col_rooms,room)
  end
  add(floor,col_rooms)
 end
 -- pick random room for boss
 -- room
 local boss_room=rnd(ends)
 boss_room.boss=true
 boss_room.boss_func=rnd(bosses)
 return floor
end
-->8
-- upgrades

function u_quad_dmg_exec()
 -- 5 seconds of quad dmg
 trans_quad_time=300
 -- no trans delay
 trans_delay=0
 -- +1 self-dmg on trans
 trans_self_dmg+=1
end

function u_heavy_hits_exec()
 -- increase ply damage
 ply_dmg+=1
 -- increase trans delay
 trans_delay+=15
end

function u_rapid_fire_exec()
 -- increase ply shoot speed
 shoot_time-=1
 -- todo: make the shoot speed
 --  weapon-specific
 -- decrease ply move speed
 ply.spd*=0.8
end

u_quad_dmg={
 desc={
  "+trans gives quad-dmg",
  "+trans is instant",
  "-you hit yourself, idiot!!",
 },
 exec=u_quad_dmg_exec,
}

u_heavy_hits={
 desc={
  "+more dmg",
  "-slow transform",
 },
 exec=u_heavy_hits_exec,
}

u_rapid_fire={
 desc={
  "+shoot faster",
  "-move slower",
 },
 exec=u_rapid_fire_exec,
}

-- shuffle bag of all upgrades
upgrades={
 u_rapid_fire,
 u_heavy_hits,
 u_quad_dmg,
}

upgrade_idx=1

function next_upgrade()
 local item=upgrades[upgrade_idx]
 upgrade_idx+=1
 if upgrade_idx>#upgrades then
  upgrade_idx=1
  shuffle(upgrades)
 end
 return item
end

function shuffle(t)
  -- do a fisher-yates shuffle
  for i = #t, 1, -1 do
    local j = flr(rnd(i)) + 1
    t[i], t[j] = t[j], t[i]
  end
end

shuffle(upgrades)
-->8
-- enemies

function enemy(pos,
               c_rad,
               c_off,
               c_size,
               s_pos,
               s_size,
               health)
 local e=entity(
  c_rad,
  c_off,
  c_size,
  s_pos.x,s_pos.y,
  s_size,
  {},
  {true,false},
  {})
 e.pos=pos
 e.health=health

 e.dmg=function(n)
  e.health-=n
 	return e.health>0
 end

 return e
end

function e_walker(pos)
 local e=enemy(
  pos,
  6,
  vec(1.5,1.5),
  vec(13,13),
  vec(56,16),
  vec(16,16),
  50) -- health

 e.spd=0.25
 
 function e.update()
  e.vel=v_mul(v_dir(ply.pos,e.pos),e.spd)
	 e.move()
	 if e.aabb(ply) then
	  dmg_ply()
	 end
 end
 
 return e
end

function e_jumper(pos)
 local e=enemy(
  pos,
  2,
  vec(2,2),
  vec(4,4),
  -- spr can be either 5 or 6
  vec(8*(5+flr(rnd())),0),
  vec(8,8),
  30) -- health

 e.dir=v_cpy(v_zero)
 e.jump_spd=128/60
 e.jump_damp=0.96
 e.jump_timer=50
 e.jump_time=50
 e.jump_ply_chance=0.25
 e.jump_perp_chance=0.5
 
 function e.update()
  e.jump_timer-=1
  if e.jump_timer==0 then
   local choice=rnd()
   local near_ply=check_vdst(e.c_center,ply.c_center)
   if choice < e.jump_ply_chance and
      near_ply then
    e.dir=v_dir(e.c_center,ply.c_center)
   elseif choice < e.jump_perp_chance and
      near_ply then
    local dir=v_perp(v_dir(e.c_center,ply.c_center))
   else
    -- todo: move away from walls
    --  on average
    e.dir=v_rnd()
	  end
   e.vel=v_mul(e.dir,e.jump_spd)
   e.jump_timer=e.jump_time
  end
	 e.move()
  e.vel=v_mul(e.vel,e.jump_damp)
	 if e.aabb(ply) then
	  dmg_ply()
	 end
 end
 
 return e
end

function e_heavy(pos)
 local state_normal=0
 local state_waitshoot=1
 local e=enemy(
  pos,
  4,
  vec(4,4),
  vec(7,8),
  -- spr can be either 5 or 6
  vec(56,0),
  vec(16,16),
  100) -- health
 
 e.spd=8/60
  
 -- will always stay away
 -- from this distance to the player
 e.min_dist=40
 -- moves towards the player until
 -- its less than this distance
 -- then attacks
 e.keep_dist=70
 -- todo: add another distance
 --  to fix for jitter between
 --  min_ist and keep_dist
 e.next_shot_delay=90
 e.pre_shot_delay=30
 
 -- 3/4 pi radians
 e.shot_arc=0.375
 e.shot_count=5
 e.shot_start_radius=8
 e.shot_life=15
 e.shot_spd=2.25
 
 e.next_shot_timer=0
 e.pre_shot_timer=0
 e.sqr_min_dist=e.min_dist*e.min_dist
 e.sqr_keep_dist=e.keep_dist*e.keep_dist
 
 function e.update()
  local d=v_dstsq(e.c_center,ply.c_center)
	 local too_close=check_vdst(e.c_center,ply.c_center,e.min_dist) and d<e.sqr_min_dist
	 local close_enough=check_vdst(e.c_center,ply.c_center,e.keep_dist) and d<e.sqr_keep_dist
	 
	 if e.next_shot_timer>0 then
	  e.next_shot_timer-=1
	  -- if i'm not able to shoot
	  -- then dont stop to shoot
	  if e.next_shot_timer>0 then
	   close_enough=false
	  end
	 end
	 
	 if e.pre_shot_timer>0 then
	  e.pre_shot_timer-=1
	  -- shoot at ply!
	  if e.pre_shot_timer==0 then
	   e.shoot_ply()
	   e.next_shot_timer=e.next_shot_delay
	  elseif not too_close then
	   return true
	  end
	 end

	 -- if im just close enough to
	 -- ply, stand still and shoot
	 if close_enough then
	  e.vel=v_cpy(v_zero)
	  e.pre_shot_timer=e.pre_shot_delay
	 end
	 
	 -- if im too close to ply
	 -- then move back in the 
	 -- opposite direction
	 if too_close then
   e.vel=v_mul(v_dir(e.c_center,ply.c_center),-e.spd)
	 elseif not close_enough then
   e.vel=v_mul(v_dir(e.c_center,ply.c_center),e.spd)
	 end
	 
	 e.move()
	 if e.aabb(ply) then
	  dmg_ply()
	 end
 end
 
 function e.shoot_ply()
  shoot_multi(
  	e.c_center,
   v_dir(e.c_center,ply.c_center),
  	e.shot_arc,
  	e.shot_count,
  	e.shot_start_radius,
  	e.shot_life,
  	e.shot_spd,
  	e.shot_fac)
 end
 
 return e
end

function lerp(a,b,t)
	return a+(b-a)*t
end

function e_boss_lilguy(tile)
 local self={
  tile=tile,
  tile_frac=v_cpy(v_zero),
  -- drawing
  sx=88,sy=16,
  spr_size=vector(16,16),
  -- collision
  radius=13,
  ox=1.5,oy=1.5,
  w=13,h=13,
  
  health=500,

  -- lilguy
  -- left-right movement
  bound_l=8,
  bound_r=104,
  tx_time_min=12,
  tx_time_max=120,
  -- firing
  shot_arc=0.2,
  shot_count=3,
  shot_start_radius=1,
  shot_life=0,
  shot_spd=0.6,
  shot_fac=b_multi,
  shoot_timer=80,
  shoot_time=90,
 }
 
 self.last_tx=center(self).x
 self.next_tx=rnd(self.bound_r-self.bound_l)+self.bound_l
 self.tx_time=flr(rnd(self.tx_time_max-self.tx_time_min)+self.tx_time_min)
 self.tx_timer=self.tx_time
 
 function self.update()
  local x=lerp(
   self.next_tx,
   self.last_tx,
   self.tx_timer/self.tx_time)
  self.tile.x=x\8
  self.tile_frac.x=x%8
  self.tx_timer-=1
  if self.tx_timer==0 then
   self.last_tx=self.next_tx
   self.next_tx=rnd(self.bound_r-self.bound_l)+self.bound_l
   self.tx_time=flr(rnd(self.tx_time_max-self.tx_time_min)+self.tx_time_min)
   self.tx_timer=self.tx_time
  end
  self.shoot_timer-=1
  if self.shoot_timer==0 then
   self:shoot_ply()
   self.shoot_timer=self.shoot_time
  end
	 if aabb(self,ply) then
	  dmg_ply()
	 end
 end

 self.shoot_ply=e_shoot_ply(self)
 self.draw=e_draw_func(self)
 self.dmg=e_dmg_func(self)
 
 return self
end

function shoot_multi(pos,dir,arc,n,r,lt,spd,b_fac)
 b_fac=b_fac or b_linear
 dir=v_rot(dir,-arc/2)
 local bul_arc=arc/(n+1)
 for i=1,n do
  dir=v_rot(dir,bul_arc)
  local bpos=v_add(pos,v_mul(dir,r))
  local btile=v_divi(bpos,8)
  local btile_frac=v_mod(bpos,8)
  local bullet=b_fac(
   btile,
   btile_frac,
   v_mul(dir,spd),
   t_enemy,
   lt)
  bullet.base_spr=3
  bullet.use_spr_lut=false
  add(bullets,bullet)
 end
end

function e_shoot_ply(e)
 return function()
  local ecenter=center(e)
  shoot_multi(
  	ecenter,
   v_dir(ecenter,center(ply)),
  	e.shot_arc,
  	e.shot_count,
  	e.shot_start_radius,
  	e.shot_life,
  	e.shot_spd,
  	e.shot_fac)
 end
end

function e_draw_func(e)
 return function()
  local xy=v_add(v_flr(topleft(e)), v_half)
	 local flip_x=xy.x<topleft(ply).x
	 sspr(
	 	e.sx,e.sy,
	 	e.spr_size.x,e.spr_size.y,
	 	xy.x,xy.y,
	 	e.spr_size.x,e.spr_size.y,
	 	flip_x,false)
	 local r1,r2=ent_rect(e)
	 rect(r1.x,r1.y,r2.x,r2.y,9)
 end
end

function e_dmg_func(e)
 return function(n)
 	e.health-=n
 	return e.health>0
 end
end

bosses={
 e_boss_lilguy,
}
-->8
-- vector.p8
-- by @thacuber2a03
-- modified by snale

function vector(x,y) return {x=x or 0,y=y or 0} end
vec=vector

function v_polar(l,a) return vector(l*sin(a),l*cos(a)) end
function v_rnd()      return v_polar(1,rnd())          end

function v_cpy(v)     return vector(v.x,v.y) end
function v_unpck(v)   return v.x, v.y end
function v_arr(v)     return {v_unpck(v)} end
function v_tostr(v)   return "["..v.x..", "..v.y.."]" end
function v_isvec(v)   return type(v)=="table" and type(v.x)=="number" and type(v.y)=="number" end
function v_eq(a,b)    return a.x==b.x and a.y==b.y end

function v_add(a,b)  return vector( a.x+b.x,  a.y+b.y) end
function v_sub(a,b)  return vector( a.x-b.x,  a.y-b.y) end
function v_mul(v,n)  return vector( v.x*n,    v.y*n  ) end
function v_div(v,n)  return vector( v.x/n,    v.y/n  ) end
function v_divi(v,n) return vector( v.x\n,    v.y\n  ) end
function v_mod(v,n)  return vector( v.x%n,    v.y%n  ) end
function v_neg(v)    return vector(-v.x,     -v.y    ) end

function v_dot(a,b)   return a.x*b.x+a.y*b.y end
function v_magsq(v)   return v_dot(v,v)          end
function v_mag(v)     return sqrt(v_magsq(v))    end
function v_dstsq(a,b) return v_magsq(v_sub(b,a)) end
function v_dst(a,b)   return sqrt(v_dstsq(a,b))  end
function v_norm(v)    return v_div(v,v_mag(v))   end
function v_perp(v)    return vector(v.y, -v.x)   end
function v_sprj(a,b)  return v_dot(a,v_norm(b))  end
function v_proj(a,b)  return v_mul(v_norm(b),v_sprj(a,b)) end
function v_dir(a,b)   return v_norm(v_sub(b,a))  end

--function v_rot(v,t)    local s,c=sin(v_ang(v)-t),cos(v_ang(v)-t) return vector(v.x*c+v.y*s, -(s*v.x)+c*v.y) end
function v_rot(v,a)    local s,c=sin(a),cos(a) return vector(c*v.x-s*v.y,s*v.x+c*v.y) end
function v_ang(v)      return atan2(v.x,v.y)    end
function v_atwds(a,b)  return v_ang(v_sub(b,a)) end

function v_lerp(a,b,t) return vector(a.x+(b.x-a.x)*t, a.y+(b.y-a.y)*t) end
function v_flr(v)      return vector(flr(v.x),flr(v.y)) end

v_right=vector( 1, 0)
v_left =vector(-1, 0)
v_down =vector( 0, 1)
v_up   =vector( 0,-1)

v_zero=vector()
v_one =vector(1,1)
v_half=vector(0.5,0.5)

v_cntr=vector(64,64)
__gfx__
66666666666776666666777666777666677667766666666676666667667666666666676666666666666666666666666666666666666666666666666666666666
66666666667007666667000767000766700770076776677667766776667760666606776666666777776666666666667777666666666667777766666667666676
66766766667007666770007670070076700000076677776666777766667706666660776666677777777766666666777777776666666777777777666670766707
66677666670000767000707670777076700000076707707667777076666077666677066666777777777776666667777777776666667777777777766670077007
66677666700770077000707670070076700000076677776666707766660677777777606666777777777776666667777777777666667777777777766670777707
66766766700000076770007667000766670000767767767777677677666677077077666666777700707776666667707777777666667777777777766667077076
66666666707777076667000766777666667007667667766776677667667707700770776666770000000776666667000777777666667777777777766666766766
66666666676666766666777666666666666776666676676666766766666700777700766666677700777776666670770077777666666777777777766666666666
77777777000000000000000066660000000066660077707066666000666677777777666666670000000766666667000077776666666777777777666666766766
77777777000000000000000066607770770706660770770766600707667777777777776666667000007666666666770007766666666670777076666667766776
77777777000000000000070066077777777770660777707066077070677767707776777666670770770766666666667777666666666700000007666667077076
77777777000000000000700060707707707707060777770760707707777666770766677766700007000076666666677007766666667000000000766667777776
77777777000000000007000060777777777777066070707007777070776667707776667766700000000076666666670700766666667000000000766667077076
77777777000000000070000007707070707070706607770700777707776677777777667766677700077766666666677077766666666777000777666666766766
77777777000000000000000007070707070707006660077007707070666677766777666666670070700766666666700700076666666700777007666666666666
77777777000000000000000000707070707070706666600007777707666677666677666666667767677666666666677677766666666677666776666666666666
66677666666667767776666666666666666666666666666666666666666666777766666666666666667666666666666666666666666666666666666666666666
66700766666670077007666666666666666666666666666666666666666667000076666666666666676677666666677777666666666666666666666666666666
66700766677700767000777666666666666666666666666666666666666670000076666666666777666666766666777777776666666666666666666666666666
66700766700000076700000766666666666666666666666666666666666700000076666666667007777666666667770777777666666666666666666666666666
67000076700000076670007766666666666666666666666666666666666707000007666666670007770767666667770077777666666666666666666666666666
70000007677700766670076666666666666666666666666666666666667077700700776666670000700766766667000000070766666666666666666666666666
70700707666670076670766666666666666666666666666666666666667070700770007666670700000766666677770007077776666666666666666666666666
67677676666667766667766666666666666666666666666666666666667070700070007666670007070766666700000077076776666666666666666666666666
66677666666667777776666666666666666666666666666666666666670007700077700766670077000766666777777000076766666666666666666666666666
66700766666770767007766666666666666666666666666666666666670000007000000766667077707666666666700000766666666666666666666666666666
66700766677000077000077666666666666666666666666666666666700000007700000766670777770766666667077077076666666666666666666666666666
67000076700000766700000766666666666666666666666666666666700000077770000766770070700776666677000700077666666666666666666666666666
67000076700000766700007766666666666666666666666666666666700000077700000767070707070707666707700000770766666666666666666666666666
70000007677000076670076666666666666666666666666666666666670077000007700766777777777776666677777777777666666666666666666666666666
77077077666770766670766666666666666666666666666666666666667766770076677666670076700766666667007770076666666666666666666666666666
76766767666667776667766666666666666666666666666666666666666666667766666666667766677666666666776667766666666666666666666666666666
66666666666666666066666666666066666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666000006666660e06660006660e06666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66660777770666660e0600ddd0060e06666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
666077777770666660e0ddddddd0e066666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
6660777777706666660ddedddedd0666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
6660777777706666660deeedeeed0666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
6660777777706666660de0eee0ed0666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66607777777066666660e00e00e06666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66660777770666666660deeeeed06666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
6660700000706666666600d0d0066666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
666077777770666666660d0d0d066666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66607777777066666660d0d0d0d06666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
6660000000006666660e0000000e0666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66607706077066666660000000006666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66660066600666666660ddd0ddd06666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666000600066666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
__label__
66611661166111111111666161111111666161111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
61616161611116111111611161111111611161111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
66616161666111111111666166611111666166611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
61116161116116111111116161611611116161611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
61116611661111111111666166616111666166611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333313333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333133333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333331333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333313333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333313333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333133333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333331333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333313333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333313333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333133333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333331333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333313333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333773333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333337557333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333337557333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333375555733333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333755775573333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333755555573333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333757777573333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333373333733333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333313333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333133333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333331333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333313333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333331333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333313333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333133333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111331333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
11111111333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333

__gff__
0000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011121111111111111111111111111010111211111111111111111111111111101112111111111111111111111111101111121111111111111111111111111010111211111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111121010111111111111111111111111111211101111111111111111111111111112101111111111111111111111111111121010111111111111111111111111111211000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111121111111111111111111010111111111211111111111111111111101111111112111111111111111111101111111111121111111111111111111010111111111211111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111121111111010111111111111111111111211111111101111111111111111111112111111101111111111111111111111121111111010111111111111111111111211111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111010111111111111111111111111111111101111111111111111111111111111101111111111111111111111111111111010111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1012111111111111111111111111111010121111111111111111111111111111101211111111111111111111111111101112111111111111111111111111111010121111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010101010101010101010101010101010101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011121111111111111111111111111111111211111111111111111111111110101112111111111111111111111111101111121111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111121111111111111111111111111111111210101111111111111111111111111112101111111111111111111111111111121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111121111111111111111111111111111111211111111111111111110101111111112111111111111111111101111111111121111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111121111111111111111111111111111111211111110101111111111111111111112111111101111111111111111111111121111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1011111111111111111111111111111111111111111111111111111111111110101111111111111111111111111111101111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1012111111111111111111111111111111121111111111111111111111111110101211111111111111111111111111101112111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000200003905000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00002b0502d0502f0503205034050000003005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000a00001f1201d1201c1201d1201c120000001812000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200003705032050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 01024344

