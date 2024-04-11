pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- game

function ply_shoot()
 local bullet=nil
 if ply.form==1 then
  bullet=b_linear(
   ply.cx,ply.cy,
   ply.sh_x*8,ply.sh_y*8,
   ply.sh_x,ply.sh_y,
   t_player)
 else
  bullet=b_seeker(
   ply.cx,ply.cy,
   ply.sh_x*8,ply.sh_y*8,
   ply.sh_x,ply.sh_y,
   ply.near_enemy,
   spd_seeker,
   t_player)
 end
 add(bullets,bullet)
 return bullet
end

function move_ent(ent)
 --
 -- horizontal
 ent.rx+=ent.dx
 local cx,cy=room.t.coord(ent.cx+1,ent.cy)
 local col_left,col_right=false,false
 if fget(mget(cx,cy),7) and ent.rx>0 then
  ent.dx=0
  ent.rx=0
  col_right=true
 end
 local cx,cy=room.t.coord(ent.cx-1,ent.cy)
 if fget(mget(cx,cy),7) and ent.rx<0 then
  ent.dx=0
  ent.rx=0
  col_left=true
 end
 while ent.rx>8 do
  ent.rx-=8
  ent.cx+=1
 end
 while ent.rx<0 do
  ent.rx+=8
  ent.cx-=1
 end
 
 --
 -- vertical
 ent.ry+=ent.dy
 local cx,cy=room.t.coord(ent.cx,ent.cy+1)
 local col_up,col_down=false,false
 if fget(mget(cx,cy),7) and ent.ry>0 then
  ent.dy=0
  ent.ry=0
  col_down=true
 end
 local cx,cy=room.t.coord(ent.cx,ent.cy-1)
 if fget(mget(cx,cy),7) and ent.ry<0 then
  ent.dy=0
  ent.ry=0
  col_up=true
 end
 while ent.ry>8 do
  ent.ry-=8
  ent.cy+=1
 end
 while ent.ry<0 do
  ent.ry+=8
  ent.cy-=1
 end
 return col_left,col_right,col_up,col_down
end

function goto_room(rx,ry,tcx,tcy,dir)
 room=floor[rx][ry]
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
 ply.cx=ix+cx
 ply.cy=iy+cy
 ply.rx=rx
 ply.ry=ry
end

function goto_first_room_dir(dir)
 for _,l in ipairs(room.links) do
  if dir==d_up or dir==d_down then 
   local ply_x=entx(ply)
   if l.dir==dir and ply_x>=l.door.x1-2 and ply_x<=l.door.x2+2 then
    goto_room(l.trx,l.try,l.tcx,l.tcy,l.dir)
   end
  elseif l.dir==dir then
   local ply_y=enty(ply)
   if l.dir==dir and ply_y>=l.door.y2-2 and ply_y<=l.door.y1+2 then
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
 ply_vert_spr=1
 ply_hori_spr=2
 ply={
  -- tile coords
  cx=7,cy=7,
  
  -- tile fraction [0, 8]
  rx=0,ry=0,
  
  -- velocity
  dx=0,dy=0,
  
  -- shoot dir
  sh_x=0,sh_y=-1,
  
  -- collision
  radius=4,
  ox=0.5,oy=0.5,
  w=7,h=7,
  
  near_enemy=nil,
  
  -- transformations
  form=1,
  trans=false,
  trans_timer=0,
  
  health=3,
  iframes=0,
  
  spr=1,
  flip_y=false,flip_x=false,
 }
 ply_spd=75/60 -- px/sec
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
 
 local plan=dungeon[floor_idx]
 floor=floor_from_plan(plan)
 room=floor[cell_x][cell_y]
 add(room.enemies,e_jumper(2,2))
 
 -- todo: do we really want
 --  to present this on startup?
 present_lvlup()
end

-->8
-- update
function _update60()
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
 ply.sh_x=dx_lut[btn_bits]
 ply.sh_y=dy_lut[btn_bits]
 ply.shoot=ply.sh_x!=0 or ply.sh_y!=0

 local use_spd=ply_spd
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
 ply.dx=dx_lut[key_bits]*use_spd
 ply.dy=dy_lut[key_bits]*use_spd
 
 update_nearest_enemy()
 update_ply_spr(key_bits,btn_bits)
 update_shoot() 
 update_bullets()
 update_enemies()
 
 if ply.iframes>0 then
  ply.iframes-=1
 end
 
 -- updating player pos from vel
 cleft,cright,cup,cdown=move_ent(ply)
 
 -- test if player touching doors
 if cleft then
  goto_first_room_dir(d_left)
 elseif cright then
  goto_first_room_dir(d_right)
 elseif cup then
  goto_first_room_dir(d_up)
 elseif cdown then
  goto_first_room_dir(d_down)
 end
 
 -- anti-cobble if diagonal
 if key_bits!=last_keys_bits and key_bits>4 then
  ply.rx=flr(ply.rx)+0.5
  ply.ry=flr(ply.ry)+0.5
 end

 -- get and clamp camera scroll
 cam_x=entx(ply)
 cam_y=enty(ply)
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
 local px,py=center(ply)
 for _,e in ipairs(room.enemies) do
  local ex,ey=center(e)
  local d=sqrdist(px,py,ex,ey)
  if d<min_dist then
   min_dist=d
   ply.near_enemy=e
  end
 end
end

function update_ply_spr(key_bits,btn_bits)
 if ply.dx!=0 or ply.dy!=0 then
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
  local bullet=bullets[i]
  local bx,by=center(bullet)
  if bx<-64 or
    bx>256 or
    by<-64 or
    by>256 then
   deli(bullets,i)
  else
   if not bullet:update() then
    deli(bullets,i)
   elseif bullet.team==t_player then
    for ei=#room.enemies,1,-1 do
     local e=room.enemies[ei]
     local ex,ey=center(e)
     if check_dist(bx,by,ex,ey) then
      local dist=sqrdist(ex,ey,bx,by)
	     local min_rad=bullet.radius+e.radius
	     if dist<min_rad*min_rad then
	      local dmg=ply_dmg*bullet.dmg_mult
	      if trans_quad_timer>0 then
	       dmg*=4
	      end
	      if not e.dmg(dmg) then
	       deli(room.enemies,ei)
	      end
	      deli(bullets,i)
	     end
     end
    end
   else
    -- we do an n-scale dist
    -- check before the real
    -- radius-check. p8 uses
    -- a fixed cap of like 32k
    -- so its pretty easy to
    -- cause an overflow when
    -- checking large distances
    local px,py=center(ply)
    if check_dist(px,py,bx,by) then
     local dist=sqrdist(px,py,bx,by)
     local min_rad=bullet.radius+ply.radius
     if dist<min_rad*min_rad then
      dmg_ply()
      deli(bullets,i)
     end
    end
   end
  end
 end
end

function update_enemies()
 for i=#room.enemies,1,-1 do
  local e=room.enemies[i]
  e.update()
 end
end
-->8
-- draw
function _draw()
 cls(0)
 if ply.health<=0 then
  draw_dead_menu()
  return
 end

 camera(cam_x-64, cam_y-64)
 room.t.draw()
 if (ply.iframes%10)<7 then
  draw_player()
 end
 draw_bullets()
 draw_enemies()
 draw_doors()
 
 camera(0,0)
 draw_ply_hp()
 
 if show_lvlup_menu then
  draw_lvlup_menu()
 end
 
 -- debug/test zone
end

function draw_player()
 spr(
  ply.spr,
  entx(ply),enty(ply),1,1,
  ply.flip_x,ply.flip_y)
 local px,py=center(ply)
 pset(px,py,8)
end

bul_spr_lut={
 {1,true,false}, -- 0
 {2,true,false}, -- 1
 {0,false,false},-- 2
 {2,false,false},-- 3
 {1,false,false},-- 4
 {2,false,true}, -- 5
 {0,false,true},-- 6
 {2,true,true},-- 7
 {1,true,false}, -- 8
}

function draw_bullets()
 for _,bullet in ipairs(bullets) do
  local angle=atan2(bullet.dx, bullet.dy)
  angle+=0.0625 -- [0.0625,1.0625)
  angle=flr(angle*8) -- [0,8]
  local bspr=bullet.base_spr
  local lut=bul_spr_lut[angle+1]
  spr(
   bspr+lut[1],
   entx(bullet),
   enty(bullet),
   1, 1,
   lut[2], lut[3])
  local bx,by=center(bullet)
  pset(bx,by,9)
 end
end

function draw_enemies()
 for i=#room.enemies,1,-1 do
  local e=room.enemies[i]
  e.draw()
 end
end

function draw_doors()
 for _,l in ipairs(room.links) do
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

-- before: 2088
-- after: 2069
ply_spr_lut={2,2,1,1,2,2,2,2}
ply_hori_lut={false,true,false,false,false,true,true}
ply_vert_lut={[4]=true}

function dot(x1,y1,x2,y2)
 return x1*x2+y1*y2
end

function sqrlen(x,y)
 return x*x+y*y
end

function sqrdist(x1,y1,x2,y2)
 return sqrlen(x2-x1,y2-y1)
end

function check_dist(x1,y1,x2,y2,a)
 -- 179 is the smallest amount we
 -- can square (e.g. in a sqrdist check)
 -- before overflowing in p8
 a=a or 179
 return abs(x2-x1)<=a and abs(y2-y1)<=a
end

function aabb(a,b)
 local ax1,ay1=entx(a)+a.ox,enty(a)+a.oy
 local ax2,ay2=ax1+a.w,ay1+a.h
 local bx1,by1=entx(b)+b.ox,enty(b)+b.oy
 local bx2,by2=bx1+b.w,by1+b.h
 return ax1<bx2 and ax2>bx1 and
  ay1<by2 and ay2>by1
end

function norm(x,y)
 local mag=sqrt(x*x+y*y)
 return x/mag,y/mag,mag
end

function dirto(fx,fy,tx,ty)
 return norm(tx-fx,ty-fy)
end

function rotate(x,y,cx,cy,a)
 local sina=sin(a)
 local cosa=cos(a)
 x-=cx
 y-=cy
 local rotx=cosa*x-sina*y
 local roty=sina*x+cosa*y
 rotx+=cx
 roty+=cy
 return rotx,roty
end

function entx(ent)
 return ent.cx*8+ent.rx
end

function enty(ent)
 return ent.cy*8+ent.ry
end

function center(ent)
 return ent.cx*8+ent.rx+4,
  ent.cy*8+ent.ry+4
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

function b_linear(cx,cy,rx,ry,dx,dy,team)
 return {
  cx=cx,cy=cy,
  rx=rx,ry=ry,
  dx=dx,dy=dy,
  base_spr=48,
  update=b_move,
  radius=1,
  team=team,
  rate_mult=1,
  dmg_mult=1,
 }
end

function b_seeker(cx,cy,rx,ry,dir_x,dir_y,target,spd,team)
 seeker={
  cx=cx,cy=cy,
  rx=rx,ry=ry,
  dx=0,dy=0,
  base_spr=32,
  dir_x=dir_x,
  dir_y=dir_y,
  spd=spd,
  -- radians turn spd per frame
  turn_spd=0.01,
  target=target,
  update=b_seeker_update,
  nofollow_dist=7.5,
  radius=1,
  team=team,
  rate_mult=4,
  dmg_mult=4,
 }
 return seeker
end

function b_seeker_update(self)
 if self.target then
  -- target dir vector
  local sx,sy=center(self)
  local px,py=center(self.target)
  local tx,ty,dist=dirto(sx,sy,px,py)
  
  -- disable following/seeking
  -- once its too close to the
  -- target
  if dist<self.nofollow_dist then
   self.target=nil
  end
  
  local perp_x=-self.dir_y
  local perp_y=self.dir_x
  local d=dot(perp_x,perp_y,tx,ty)
  if d<0 then
   self.dir_x,self.dir_y=rotate(self.dir_x,self.dir_y,0,0,self.turn_spd)
  elseif d>0 then
   self.dir_x,self.dir_y=rotate(self.dir_x,self.dir_y,0,0,-self.turn_spd)
  end
  
  perp_x=-self.dir_y
  perp_y=self.dir_x
  local new_d=dot(perp_x,perp_y,tx,ty)
  
  -- can this be replaced with sgn(d) != sgn(new_d)?
  --if d>0 and new_d<0 or d<0 and new_d>0 then
  if sgn(d) != sgn(new_d) then
   self.dir_x,self.dir_y=norm(tx,ty)
  end
 end
 
 self.dx=self.dir_x*self.spd
 self.dy=self.dir_y*self.spd
 
 b_move(self)
 return true
end

function b_move(self)
 --
 -- horizontal
 self.rx+=self.dx
 while self.rx>8 do
  self.rx-=8
  self.cx+=1
 end
 while self.rx<0 do
  self.rx+=8
  self.cx-=1
 end
 
 --
 -- vertical
 self.ry+=self.dy
 while self.ry>8 do
  self.ry-=8
  self.cy+=1
 end
 while self.ry<0 do
  self.ry+=8
  self.cy-=1
 end
 return true
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


floor_plans={
 fp_1,
 fp_2
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
 local floor={}
 for _,col in ipairs(plan) do
  local col_rooms={}
  for _,cell in ipairs(col) do
   add(col_rooms,{
    t=cell.t,
    links=cell.links,
    enemies={},
   })
  end
  add(floor,col_rooms)
 end
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
 ply_spd*=0.8
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

function e_walker(cx,cy)
 self={
  cx=cx,cy=cy,
  rx=0,ry=0,
  dx=0,dy=0,
  -- collision
  radius=13,
  ox=1.5,oy=1.5,
  w=13,h=13,
  
  health=50,
  spd=15/60,
 }
 
 function self.update()
	 self.dx,self.dy=dirto(entx(self),enty(self),entx(ply),enty(ply))
	 self.dx*=self.spd
	 self.dy*=self.spd
	 move_ent(self)
	 local px,py=center(ply)
	 local ex,ey=center(self)
	 if aabb(self,ply) then
	  dmg_ply()
	 end
 end
 
 function self.draw()
	 local x=flr(entx(self))+0.5
	 local y=flr(enty(self))+0.5
	 local flip_x=x<entx(ply)
	 spr(39,x,y,2,2,flip_x,false)
 end
 
 function self.dmg(n)
  self.health-=n
  return self.health>0
 end
 
 return self
end

function e_jumper(cx,cy)
 self={
  cx=cx,cy=cy,
  rx=0,ry=0,
  dx=0,dy=0,
  -- collision
  radius=2,
  ox=2,oy=2,
  w=4,h=4,
  
  health=30,
  
  dir_x=0,dir_y=0,
  jump_spd=128/60,
  jump_damp=0.96,
  jump_timer=50,
  jump_time=50,
  jump_ply_chance=0.25,
  jump_perp_chance=0.5,
 }
 
 function self.update()
	 local px,py=center(ply)
  self.jump_timer-=1
  if self.jump_timer==0 then
   local ex,ey=center(self)
   local choice=rnd()
   local near_ply=check_dist(ex,ey,px,py)
   if choice < self.jump_ply_chance and
      near_ply then
    self.dir_x,self.dir_y=dirto(ex,ey,px,py)
   elseif choice < self.jump_perp_chance and
      near_ply then
    local dir_x,dir_y=dirto(ex,ey,px,py)
    self.dir_x=-dir_y
    self.dir_y=dir_x
   else
    -- todo: move away from walls
    --  on average
	   local a=rnd()
	   self.dir_x=cos(a)
	   self.dir_y=sin(a)
	  end
   self.dx=self.dir_x*self.jump_spd
   self.dy=self.dir_y*self.jump_spd
   self.jump_timer=self.jump_time
  end
	 move_ent(self)
	 self.dx*=self.jump_damp
	 self.dy*=self.jump_damp
	 local ex,ey=center(self)
	 if aabb(self,ply) then
	  dmg_ply()
	 end
 end
 
 function self.draw()
	 local x=flr(entx(self))+0.5
	 local y=flr(enty(self))+0.5
	 local flip_x=x<entx(ply)
	 spr(6,x,y,1,1,flip_x,false)
 end
 
 function self.dmg(n)
  self.health-=n
  return self.health>0
 end
 
 return self
end

__gfx__
66666666666776666666777666666666677667766666666676666667667666666666676666666666666666666666666666666666666666666666666666666666
66666666667007666667000766666666700770076776677667766776667760666606776666666777776666666666667777666666666667777766666667666676
66766766667007666770007666677666700000076677776666777766667706666660776666677777777766666666777777776666666777777777666670766707
66677666670000767000707666700766700000076707707667777076666077666677066666777777777776666667777777776666667777777777766670077007
66677666700770077000707666700766700000076677776666707766660677777777606666777777777776666667777777777666667777777777766670777707
66766766700000076770007666677666670000767767767777677677666677077077666666777700707776666667707777777666667777777777766667077076
66666666707777076667000766666666667007667667766776677667667707700770776666770000000776666667000777777666667777777777766666766766
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
66700766677700767000777666666666666666666666666666666666666670000076666666666777666666766667777777766666666666666666666666666666
66700766700000076700000766666666666666666666666666666666666700000076666666667007777666666677777707776666666666666666666666666666
67000076700000076670007766666666666666666666666666666666666707000007666666670007770767666677777007776666666666666666666666666666
70000007677700766670076666666666666666666666666666666666667077700700776666670000700766766707000000076666666666666666666666666666
70700707666670076670766666666666666666666666666666666666667070700770007666670700000766667777070007777666666666666666666666666666
67677676666667766667766666666666666666666666666666666666667070700070007666670007070766667767077000000766666666666666666666666666
66677666666667777776666666666666666666666666666666666666670007700077700766670077000766666767000077777766666666666666666666666666
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
