pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- vector.p8
-- by @thacuber2a03

-- modified by snale
-- n.b. several unused functions
-- have been removed, to save
-- tokens

function vec(x,y) return {x=x or 0,y=y or 0} end

function v_polar(l,a) return vec(l*cos(a),l*sin(a)) end
function v_rnd()      return v_polar(1,rnd())          end

function v_cpy(v)     return vec(v.x,v.y) end
function v_unpck(v)   return v.x, v.y end
function v_eq(a,b)    return a.x==b.x and a.y==b.y end

function v_add(a,b)  return vec( a.x+b.x,  a.y+b.y) end
function v_sub(a,b)  return vec( a.x-b.x,  a.y-b.y) end
function v_mul(v,n)  return vec( v.x*n,    v.y*n  ) end
function v_div(v,n)  return vec( v.x/n,    v.y/n  ) end
function v_divi(v,n) return vec( v.x\n,    v.y\n  ) end
function v_neg(v)    return vec(-v.x,     -v.y    ) end

function v_dot(a,b)   return a.x*b.x+a.y*b.y end
function v_magsq(v)   return v_dot(v,v)          end
function v_mag(v)     return sqrt(v_magsq(v))    end
function v_dstsq(a,b) return v_magsq(v_sub(b,a)) end
function v_dst(a,b)   return sqrt(v_dstsq(a,b))  end
function v_norm(v)    return v_div(v,v_mag(v))   end
function v_perp(v)    return vec(v.y, -v.x)   end
function v_dir(a,b)   return v_norm(v_sub(b,a))  end

function v_rot(v,a)    local s,c=sin(a),cos(a) return vec(c*v.x-s*v.y,s*v.x+c*v.y) end
function v_ang(v)      return atan2(v.x,v.y)    end

function v_lerp(a,b,t) return vec(a.x+(b.x-a.x)*t, a.y+(b.y-a.y)*t) end
function v_flr(v)      return vec(flr(v.x),flr(v.y)) end

v_zero=vec()
v_one =vec(1,1)
v_half=vec(0.5,0.5)

v_cntr=vec(64,64)
-->8
-- events
ev_meter_start={}
ev_meter_end={}
ev_ply_hit={}
ev_enemy_hit={}
ev_enemy_dead={}

function handle_ev(ev, arg)
 for f in all(ev) do
  if f then f(arg) end
 end
end

function handle_meter_start()
 handle_ev(ev_meter_start)
end

function handle_meter_end()
 handle_ev(ev_meter_end)
end

function handle_ply_hit()
 handle_ev(ev_ply_hit)
end

function handle_enemy_hit(arg)
 handle_ev(ev_enemy_hit,arg)
end

function handle_enemy_dead(arg)
 handle_ev(ev_enemy_dead,arg)
end
-->8
-- game
function shuffle(t)
 -- do a fisher-yates shuffle
 for i=#t,1,-1 do
 local j=flr(rnd(i))+1
  t[i],t[j]=t[j],t[i]
 end
end

function has_col(x,y)
 x,y=room.t.coord(x\8,y\8)
 return fget(mget(x,y),7)
end

function state_normal()
 if room.boss then
  music_boss_loop.play()
 else
  music_loop1.play()
 end
 state_update=update_normal
 state_draw=draw_normal
end

function goto_room(rx,ry,tcx,tcy,dir)
 sfx_door_enter.play()
 next_room=floor[rx][ry]
 bullets={}
 if next_room.boss then 
  music(-1,500)
  state_boss_room_enter()
  return
 end
 -- todo: add a timer for
 --  switching to a different
 --  track on non-state room
 --  changes
 room=next_room
 room.locked=#room.enemies>0
 local ix=tcx*16*8
 local iy=tcy*16*8
 local cx,cy,rx,ry=0,0,0,0
 if dir==d_up then
  -- end up at bottom of cell
  -- half in screen
  cx=7*8
  cy=14*8
  rx=4
 elseif dir==d_down then
  cx=7*8
  cy=2*8
  rx=4
 elseif dir==d_left then
  cx=14*8
  cy=7*8
  ry=4
 elseif dir==d_right then
  cx=2*8
  cy=7*8
  ry=4
 end
 ply.pos.x=ix+cx+rx-ply.s_size.x/2
 ply.pos.y=iy+cy+ry-ply.s_size.y/2
end

function goto_first_room_dir(dir)
 for l in all(room.links) do
  local ppos=ply.c_center
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
 if ply_eat_hit then
  ply_eat_hit=false
  -- giving the player some
  -- leeway for touch-damage
  ply.iframes=15
  return
 end
 ply.health-=n or 1
 -- 2 seconds of iframes
 ply.iframes=120
 handle_ply_hit()
 if ply.health>0 then
  hitsleep=1
  sfx_ply_dmg.play()
 else
  -- after hitsleep is over, switch
  -- to dead state
  music(-1)
  hitsleep=60
  sfx_ply_dmg_last.play()
  add(hitstun_awaiters,state_dead)
 end
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
  pos=v_cpy(v_zero),
  -- subpixel pos
  subpos=v_cpy(v_zero),
  -- velocity
  vel=v_cpy(v_zero),
  -- knockback
  knock=v_cpy(v_zero),
  
  -- collision
  -- 
  c_active=true,
  -- bullet collision radius
  c_rad=c_rad or 1,
  -- aabb's offset from pos
  c_off=c_off or v_cpy(v_zero),
  -- aabb's size
  c_size=c_size or v_cpy(v_zero),
  
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
 
 function ent.include(t)
  for k,v in pairs(t) do
   ent[k]=v
  end
 end
 
 -- aabb/rect overlap test
 function ent.aabb(other)
	 local a1,a2=ent.c_p1,ent.c_p2
	 local b1,b2=other.c_p1,other.c_p2
	 return a1.x<b2.x and a2.x>b1.x and
	  a1.y<b2.y and a2.y>b1.y
	end
	
	-- circle overlap test
	function ent.circ(o)
	 local min_d=ent.c_rad+o.c_rad
	 local d=v_dstsq(ent.c_center,o.c_center)
	 return ent.near(o) and d<(min_d*min_d)
	end
	
	function ent.near(o,d)
	 d=d or 127
	 return abs(o.pos.x-ent.pos.x)<=d and
	  abs(o.pos.y-ent.pos.y)<=d
	end
	
	function ent.init()
	 ent.upd_coords()
	 ent.upd_spr()
	end
 
  function ent.upd_coords()
  ent.c_p1=v_add(ent.pos,ent.c_off)
  ent.c_p2=v_add(ent.c_p1,ent.c_size)
  ent.c_center=v_lerp(ent.c_p1,ent.c_p2,0.5)
  ent.s_center=v_add(ent.pos,v_div(ent.s_size,2))
 end
 
 function ent.upd_spr()
  local s=ent.s_lut[ent.s_dir_idx]
  if s==nil then
	  ent.use_sx=ent.s_x
	  ent.use_sy=ent.s_y 
   ent.flip_x=ent.s_hori_lut[ent.s_dir_idx]
   ent.flip_y=ent.s_vert_lut[ent.s_dir_idx]
	  return
  end
  ent.use_sx=8*(s%16)
  ent.use_sy=8*(s\16)
  ent.flip_x=ent.s_hori_lut[ent.s_dir_idx]
  ent.flip_y=ent.s_vert_lut[ent.s_dir_idx]
 end

 function ent.move()
  if not v_eq(ent.knock,v_zero) then
   ent.subpos=v_add(ent.subpos,ent.knock)
   if v_magsq(ent.knock)<=1 then
    ent.knock=v_cpy(v_zero)
   else
    ent.knock=v_sub(ent.knock,v_norm(ent.knock))
   end
  end
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
	   if ent.knock.x>0 then
	    ent.knock.x*=-1
	   end
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
	   if ent.knock.x<0 then
	    ent.knock.x*=-1
	   end
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
	   if ent.knock.y>0 then
	    ent.knock.y*=-1
	   end
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
	   if ent.knock.y<0 then
	    ent.knock.y*=-1
	   end
	  else
		  ent.subpos.y+=1
		  ent.pos.y-=1
		 end
	 end
	 
	 return col_left,col_right,col_up,col_down
	end
 
 function ent.draw()
  sspr(
   ent.use_sx,ent.use_sy,
   ent.s_size.x,ent.s_size.y,
   ent.pos.x,ent.pos.y,
   ent.s_size.x,ent.s_size.y,
   ent.flip_x,ent.flip_y)
 end
 
 return ent
end

function setup_next_floor()
 local plan=rnd(floor_plans)
 -- if room is nil, then we havent
 -- set up a floor yet, and this is
 -- the first floor
 floor=floor_from_plan(plan,room==nil)
 cell_x,cell_y=3,3
 room=floor[cell_x][cell_y]
 room.locked=#room.enemies>0
 boss=nil
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
 ply.spd=75/60 -- px/sec
 ply.init()
 
 max_health=3
 
 ply_source_ang=0
 ply_sources={}
 add_source()
 
 ply_meter=0
 max_meter=50
 meter_decay_spd=1/3
 
 ply_items={}
 ply_spd_shoot_mult=0.85
 
 bullets={}
 spr_bullet=3
 
 clears={}
 clear_spd=3
 
 cell_x=3
 cell_y=3
 
 cam_x=64
 cam_y=64
 
 -- stats
 enemies_killed=0
 rooms_cleared=0
 floors_cleared=0
 items_got=0
 time_minutes=0
 time_seconds=0
 
 -- hitsleep & shake
 hitsleep=0
 hitstun_awaiters={}

 setup_next_floor()

 --add(room.enemies,e_walker(vec(20,20)))
 --add(room.enemies,e_jumper(vec(20,20)))
 --add(room.enemies,e_heavy(vec(20,20)))
 
 --room.enemies[1].init()
 
 -- todo: do we really want
 --  to present this on startup?
 --present_lvlup()
 state_normal()
end

function add_next_item(pos)
 local item=next_item_chance()(pos)
 item.init()
 add(room.items,item)
end

function add_heart(pos)
 local h=heart(pos)
 h.init()
 add(room.hearts,h)
end

function update_source_offsets()
 local assumed_count=max(#ply_sources,4)
 for i=2,#ply_sources do
  ply_sources[i].off=(i-1)/assumed_count
 end
end

function add_source(fac,delay,spd,dmg) local s=source(fac,delay,spd,dmg)
 add(ply_sources,s)
 update_source_offsets()
 return s
end

function del_source(s)
 del(ply_sources,s)
 update_source_offsets()
end

function source(fac,delay,spd,dmg)
 local s={
  off=0,
  pos=v_cpy(ply.s_center),
  fac=fac or b_linear,
  delay=delay or 10,
  spd=spd or 2.3,
  dmg=dmg or 3,
  timer=0,
 }

 function s.try_shoot()
  if s.timer>0 then return end
  s.timer=s.delay
  return s.fac(
   v_cpy(s.pos), -- pos
   v_mul(ply.sh_dir,s.spd), -- vel
   t_player, -- team
   0, -- lifetime
   s.dmg, -- dmg
   ply.near_enemy) -- target
 end

 return s
end

function add_clear(pos)
 add(clears,{pos=pos,r=1})
end
-->8
-- normal update
function _update60()
 state_update()
 if ply.health>0 then
  time_seconds+=1/60
	 if time_seconds>60 then
	  time_seconds-=60
	  time_minutes+=1
	 end
 end
end

function update_normal()
 if hitsleep>0 then
  hitsleep-=1
  return
 end
 
 for i=#hitstun_awaiters,1,-1 do
  hitstun_awaiters[i]()
  deli(hitstun_awaiters,i)
 end

 -- grab btn_lut-mapped input
 -- keys() is wasd
 -- btn() is ⬅️➡️⬆️⬇️
 current_keys=keys()
 local key_bits=btn_lut[current_keys&0b1111]
 local btn_bits=btn_lut[btn()&0b1111]
 ply.sh_dir=vec(dx_lut[btn_bits],dy_lut[btn_bits])
 ply.shoot=ply.sh_dir.x!=0 or ply.sh_dir.y!=0

 local use_spd=ply.spd
 if ply.shoot then
  use_spd*=ply_spd_shoot_mult
  ply_source_ang=v_ang(ply.sh_dir)
 end

 for source in all(ply_sources) do
  local source_ang=ply_source_ang+source.off
  source.pos=v_add(ply.s_center,v_sub(v_polar(10,source_ang),vec(2,2)))
  if source.timer>0 then
   source.timer-=1
  end
 end
 
 -- shift uses meter, only if
 -- player isnt already using
 -- meter
 if not use_meter and ply_meter>=max_meter then
	 use_meter=keyp_shift() and ply_meter>=max_meter
	 -- if the player just used meter,
	 -- trigger meter_start events
	 if use_meter then
 	 handle_meter_start()
	 end
 end
 
 if use_meter then
  ply_meter=max(ply_meter-meter_decay_spd,0)
  use_meter=ply_meter>0
  if not use_meter then
   handle_meter_end()
  end
 end
 
 -- updating player spd from
 -- player input direction
 ply.vel=vec(
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
 update_clears()
 update_bullets()
 update_enemies()
 
 if ply.iframes>0 then
  ply.iframes-=1
 end
 
 -- updating player pos from vel
 cleft,cright,cup,cdown=ply.move()
 
 -- test if player touching doors
 if not room.boss then
  if not room.locked then
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
 elseif boss.health<=0 and boss.circ(ply) then
  -- if we're in boss room and
  -- player has moved into the
  -- boss hole, goto next floor
  music(-1,500)
  state_floor_end()
  floors_cleared+=1
  -- clear all bullets
  bullets={}
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
 
 -- allow player to select &
 -- acquire an item, with space
 local selected_item=false
 for item in all(room.items) do
  if item.aabb(ply) and keyp_space() then
   item.acquire()
   items_got+=1
   selected_item=true
   sfx_menu_sel.play()
   add(ply_items,item)
   break
  end
 end
 
 for hi=#room.hearts,1,-1 do
  if room.hearts[hi].aabb(ply) and ply.health<max_health and ply.health>0 then
   -- todo: heart pickup sfx
   ply.health+=1
   deli(room.hearts,hi)
  end
 end
 
 -- remove all items after player
 -- chooses an item
 if selected_item then
  room.items={}
 end

 -- get and clamp camera scroll
 cam_x,cam_y=v_unpck(ply.pos)
 clamp_scroll_to_room()
 
 last_keys_bits=key_bits
 last_keys=current_keys
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
 if ply.shoot then
		local fired=false
	 for source in all(ply_sources) do
	  local bul=source.try_shoot()
	  add(bullets,bul)
	  if bul then
	   fired=true
	  end
	 end
	 if fired then
	  sfx_shoot.play()
	 end
 end
end

function update_clears()
 -- update clears - if bullets
 -- are within the clear range,
 -- then delete the bullets
 for ci=#clears,1,-1 do
  local c=clears[ci]
  c.r+=clear_spd
  if c.r>=127 then
   deli(clears,ci)
   bullets={}
  else
	  for bi=#bullets,1,-1 do
	   local b=bullets[bi]
	   if v_dstsq(c.pos,b.pos)<c.r*c.r then
	    deli(bullets,bi)
	   end
	  end
	 end
 end
end

function test_ply_bul_bullets(bul)
 -- check intersection with
 -- other bullets if it has a
 for other_bul in all(bullets) do
  if bul!=other_bul and other_bul.team==t_enemy and other_bul.circ(bul) then
   bul.destroy=true
   if other_bul.destruct_mode==2 then
    -- only destroy player bullet
    other_bul.destroy=true
   end
  end
 end
end

function test_ply_bul_enemies(bul)
	for ei=#room.enemies,1,-1 do
  local e=room.enemies[ei]
  if bul.circ(e) then
   local dmg=bul.dmg
   -- dealing damage adds
   -- meter
   enemy_hit_arg={
    meter_gain=dmg
   }
   
   handle_enemy_hit(enemy_hit_arg)
   
   if not use_meter then
    ply_meter=min(ply_meter+enemy_hit_arg.meter_gain,max_meter)
   end
   
   if not e.dmg(dmg) then
    deli(room.enemies,ei)
    
    enemies_killed+=1
    
    if not room.boss then
     -- only triggers if the
     -- enemy is not the boss
     handle_enemy_dead(e)
     -- small chance of 
     -- dropping a heart or an
     -- item
     if rnd()<0.015 then
      if rnd(0.66) then
       add_heart(e.pos)
      else
	      add_next_item(e.pos)
	     end
     end
    end
    
    if #room.enemies==0 then
     if room.boss then
      -- todo: make less abrupt,
      --  with a timer or something
      music_loop2.play()
      -- if player kills boss, boss
      -- drops an item in the center
      -- of the room
      -- theres a 50% chance for the
      -- boss to drop a heart
      -- instead of an item
      if ply.health<max_health and rnd()<0.5 then
       add_heart(v_cntr)
      else
       add_next_item(vec(56,56))
      end
     end
     -- unlock room if all 
     -- enemies are gone
     room.locked=false
     rooms_cleared+=1
    end
   end
   bul.destroy=true
  end
 end
end

function update_bullets()
 for bul in all(bullets) do
  if not bul.destroy then
	  bul.upd_coords()
	  bul.upd_spr()
	  local bx,by=v_unpck(bul.s_center)
	  if bx<0 or
	    bx>256 or
	    by<0 or
	    by>256 then
	   -- too far away, remove
	   bul.destroy=true
	  else
	   -- update bullets & handle
	   -- collisions with player &
	   -- other entities
	   if not bul.update() then
	    bul.destroy=true
	   elseif bul.team==t_player then
	    test_ply_bul_bullets(bul)
	    if not bul.destroy then
	     test_ply_bul_enemies(bul)
	    end
	   elseif bul.circ(ply) then
	    dmg_ply()
	    if bul.del_on_dmg then
	     bul.destroy=true
	    end
	   end
	  end
	 end
 end
 
 for i=#bullets,1,-1 do
  local bul=bullets[i]
  
  if bul.destroy then
	  if bul.multi_cnt then
	   bul.multi_cnt-=1
	   bul.destroy=bul.multi_cnt==0
	  end
	  if bul.destroy then
    deli(bullets,i)
   end
  end
 end
end

function update_enemies()
 for e in all(room.enemies) do
  e.upd_coords()
  e.upd_spr()
  e.update()
 end
end
-->8
-- normal draw
function _draw()
 state_draw()
end

function draw_normal()
 cls(0)

 camera(cam_x-64, cam_y-64)
 if room.boss and boss then
  draw_boss_room()
 else
  room.t.draw()
  draw_doors()
 end
 
 if (ply.iframes%10)<7 or hitsleep>0 then
  for source in all(ply_sources) do
   spr(47,source.pos.x,source.pos.y)
  end 
  ply.draw()
 end
 draw_all(bullets)
 draw_all(room.hearts)
 draw_all(room.enemies)
 draw_all(room.items)
 
 for clear in all(clears) do
  circ(clear.pos.x,clear.pos.y,clear.r,7)
 end
 
 camera(0,0)
 draw_ply_hud()
 
 -- debug/test zone
end

function draw_boss_room()
 map(1,1,1,1,13,13)
 rect(0,0,127,127,7)
 if boss.health<0 then
  spr(35,
   boss.pos.x,boss.pos.y,
   2,2)
  spr(45,
   boss.pos.x,boss.pos.y-12+4*sin(0.5*time()),
   2,2)
 end
end

function draw_item_room()
 map(1,1,1,1,13,13)
 rect(0,0,127,127,7)
end

function draw_all(t)
 for item in all(t) do
  item.draw()
 end
end

function draw_doors()
 for l in all(room.links) do
  local use_spr=l.door.spr1
  if room.locked then
   use_spr=64
   if l.dir==d_right or l.dir==d_left then
    use_spr=80
   end
  elseif floor[l.trx][l.try].boss then
   use_spr=37
   if l.dir==d_right or l.dir==d_left then
    use_spr=53
   end
  end
  
  spr(use_spr,l.door.x1,l.door.y1,1,1,l.door.flip_x,l.door.flip_y)
  spr(use_spr+1,l.door.x2,l.door.y2,1,1,l.door.flip_x,l.door.flip_y)
 end
end

function draw_ply_hud()
 -- hp
 for i=0,ply.health-1 do
  spr(4,1+i*9,119)
 end
 for i=ply.health,max_health-1 do
  spr(63,1+i*9,119)
 end
 
 -- meter
 local frac=1-(ply_meter/max_meter)
 rect(1,83,5,117,7)
 rectfill(2,84,4,116,0)
 rectfill(3,lerp(85,115,frac),3,115,7)
end

-->8
-- input util
unit_45=0.707
btn_lut={[0]=0,1,2,0,3,5,6,3,4,8,7,4,0,1,2,0}
dx_lut={[0]=0,-1,1,0,0,-0.707,0.707,0.707,-0.707}
dy_lut={[0]=0,0,0,-1,1,-0.707,-0.707,0.707,0.707}

-- remapping keyboards
function keys()
 -- l r u d shift space
 return (tonum(stat(28, 4)))|
        (tonum(stat(28, 7))<<1)|
        (tonum(stat(28,26))<<2)|
        (tonum(stat(28,22))<<3)|
        (tonum(stat(28,225))<<4)|
        (tonum(stat(28,44))<<5)
end

function keyp(b)
 return (last_keys&b!=b) and current_keys&b==b
end

function keyp_shift()
 return keyp(0b10000)
end

function keyp_space()
 return keyp(0b100000)
end

-->8
-- room shapes
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
 {
  w=1,h=1,
  draw=room_square,
  coord=coord_square,
 },
 {
  w=1,h=2,
  draw=room_tall,
  coord=coord_tall,
 },
 {
  w=2,h=1,
  draw=room_long,
  coord=coord_long,
 },
 {
  w=2,h=2,
  draw=room_corner_ne,
  coord=coord_corner_ne,
 },
 {
  w=2,h=2,
  draw=room_corner_se,
  coord=coord_corner_se,
 },
 {
  w=2,h=2,
  draw=room_corner_nw,
  coord=coord_corner_nw,
 },
 {
  w=2,h=2,
  draw=room_corner_sw,
  coord=coord_corner_sw,
 }
}

-->8
-- ent & vectors util
function check_vdst(a,b,d)
 d=d or 127
 return abs(a.x-b.x)<=d and abs(a.y-b.y)<=d
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
-- bullets
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
                dmg,
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

 b.include{
	 c_active=false,
	 pos=v_sub(v_add(v_flr(pos),v_half),vec(3.5,3.5)),
	 vel=vel,
	 team=team,
	 lifetime=lifetime or 0,
	 dmg=dmg,
	 del_on_dmg=true,
	 destruct_mode=0,
 }
 -- destruct_mode:
 --  0 is nothing
 --  1 is destory collided bullets
 --  2 is destroy self & collided bullets
 
 b.update=function()
  if b.lifetime==-1 then
   return false
  end
  b.move()
  if b.lifetime>0 then
   b.lifetime-=1
   if b.lifetime==0 then
    -- mark this bullet to be
    -- deleted next frame. we
    -- do this so that it still
    -- has a chance to dmg other
    -- entities/the player
    b.lifetime=-1
   end
  end
  return true
 end

 function b.upd_spr()
	 local angle=v_ang(b.vel)
	 angle+=0.0625 -- [0.0625,1.0625)
	 angle=flr(angle*8)+1 -- [1,9]

	 local s=b.s_lut[angle]
	 if s==nil then
	  b.use_sx=b.s_x
	  b.use_sy=b.s_y
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

function b_linear(pos,vel,team,lifetime,dmg)
 local b=bullet(
  pos,
  vel,
  2,
  vec(8,8),
  vec(0,24),
  vec(8,8),
  team,
  lifetime,
  dmg)

 return b
end

function b_multi(pos,vel,team,lifetime,dmg)
 local b=bullet(
  pos,
  vel,
  1.5,
  vec(5,5),
  vec(24,0),
  vec(5,5),
  team,
  lifetime,
  dmg,
  {},{},{})
 
 b.include{
	 multi_ang=0,
	 multi_rot_spd=1/120,
	 multi_rad_spd=0,
	 multi_radius=2.5,
	 multi_cnt=3,
	 buls={},
 }
 
 b.multi_base_spd=b.multi_rot_spd
 
 function b.update()
	 if #b.buls!=b.multi_cnt then
	  b.buls={}
	  for i=1,b.multi_cnt do
	  	add(b.buls, {sprpos=v_cpy(v_zero),pos=v_cpy(v_zero)})
	  end
	 end
	 if b.multi_rad_spd>0 then
	  b.multi_radius+=b.multi_rad_spd
		 -- linear velocity to angular velocity
		 -- w=v/r
		 b.multi_rot_spd=b.multi_base_spd/b.multi_radius
	 end
	 for i,bul in ipairs(b.buls) do
	  local frac=i/b.multi_cnt
	  -- bul center (used for collision)
	  bul.pos.x=b.s_center.x+cos(b.multi_ang+frac)*b.multi_radius
	  bul.pos.y=b.s_center.y+sin(b.multi_ang+frac)*b.multi_radius
	  -- bul sprite pos
	  bul.sprpos=v_sub(bul.pos,v_div(b.s_size,2))
	 end
	 b.multi_ang+=b.multi_rot_spd
  b.move()
  return b.multi_radius<128
 end
 
 function b.circ(o)
	 for bul in all(b.buls) do
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
 
 function b.draw()
  for bul in all(b.buls) do
   sspr(
	   b.use_sx,b.use_sy,
	   b.s_size.x,b.s_size.y,
	   bul.sprpos.x,bul.sprpos.y,
	   b.s_size.x,b.s_size.y)
  end
 end

 return b
end

function b_seeker(pos,vel,team,lifetime,dmg,target)
 local b=bullet(
  pos,
  v_cpy(v_zero),
  2,
  vec(8,8),
  vec(0,16),
  vec(8,8),
  team,
  lifetime,
  dmg)
 
 -- overriding base values
 b.rate_mult=4
 b.dmg_mult=4
 
 -- seeker stuff
 b.nofollow_dist=7.5
 b.turn_spd=0.01
 b.spd=v_mag(vel)
 b.dir=v_div(vel, b.spd) -- v_norm but saving a division
 b.target=target
 
 function b.update()
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

floor_plans={
 ",,,,,,,,1,1,0,0,3,3,4,0,0,,,,1,2,0,0,1,3,4,0,0,0,0,3,4,3,0,0,1,3,0,0,0,3,3,0,0,0,0,1,3,5,0,0,0,0,2,2,4,0,0,1,1,0,0,0,3,4,0,0,,,1,3,0,0,2,3,3,0,0,0,0,1,4,4,0,0,0,0,3,5,3,0,0,1,1,0,0,0,4,3,0,0,,,,1,1,0,0,2,4,3,0,0,,,",
 "1,1,0,0,3,2,1,0,0,,1,2,0,0,1,1,4,0,0,0,0,3,2,3,0,0,1,1,0,0,0,1,3,0,0,,1,2,0,0,1,2,2,0,0,0,0,2,1,1,0,0,1,2,0,0,1,2,3,0,0,0,0,0,2,1,0,0,1,3,0,0,3,3,3,0,0,0,0,0,2,2,0,0,0,0,2,1,3,0,0,1,1,0,0,3,3,4,0,0,,,,1,3,0,0,1,3,4,0,0,0,0,2,2,3,0,0,0,0,3,4,3,0,0,1,2,0,0,2,2,4,0,0,0,0,0,3,3,0,0,,,1,1,0,0,1,4,3,0,0,1,2,0,0,2,3,3,0,0,0,0,0,4,2,0,0,,,,,,,,",
 ",,,,,,1,2,0,0,3,3,2,0,0,0,0,1,2,3,0,0,1,1,0,0,0,2,2,0,0,,,1,1,0,0,1,3,2,0,0,1,3,0,0,3,4,2,0,0,0,0,2,2,2,0,0,0,0,0,3,1,0,0,1,2,0,0,1,3,4,0,0,0,0,3,4,3,0,0,1,1,0,0,0,3,3,0,0,,,1,2,0,0,1,4,3,0,0,0,0,2,3,2,0,0,1,2,0,0,2,3,3,0,0,0,0,0,4,2,0,0,,,,,,,,",
 ",,,,,,,,1,1,0,0,3,3,4,0,0,,,1,1,0,0,3,4,2,0,0,1,1,0,0,1,3,4,0,0,1,3,0,0,2,2,4,0,0,0,0,3,4,4,0,0,0,0,0,3,3,0,0,,,1,2,0,0,1,4,3,0,0,0,0,2,3,2,0,0,1,3,0,0,1,4,4,0,0,0,0,0,4,2,0,0,0,0,3,5,3,0,0,1,2,0,0,2,3,4,0,0,0,0,0,4,3,0,0,,,,1,1,0,0,2,4,3,0,0,,,",
 ",,1,1,0,0,3,2,3,0,0,,,,,1,2,0,0,3,3,3,0,0,0,0,2,1,3,0,0,,,,1,1,0,0,1,3,3,0,0,1,4,0,0,1,3,4,0,0,0,0,2,2,3,0,0,0,0,3,4,3,0,0,0,0,0,3,2,0,0,1,2,0,0,0,3,3,0,0,0,0,1,3,5,0,0,1,1,0,0,0,3,4,0,0,,,1,1,0,0,2,3,3,0,0,,,,,,,,",
 ",,,,,,,,,,1,2,0,0,1,3,2,0,0,0,0,3,4,1,0,0,1,2,0,0,1,3,3,0,0,0,0,0,3,1,0,0,1,2,0,0,3,4,3,0,0,0,0,0,3,2,0,0,,,1,1,0,0,2,3,1,0,0,,1,3,0,0,1,4,4,0,0,0,0,3,5,3,0,0,0,0,2,3,3,0,0,1,2,0,0,0,4,3,0,0,0,0,1,4,5,0,0,1,1,0,0,0,4,4,0,0,,,1,1,0,0,2,4,3,0,0,,,",
 ",,,,,,,1,2,0,0,3,3,3,0,0,0,0,1,2,4,0,0,1,2,0,0,0,2,3,0,0,0,0,3,3,4,0,0,,,1,1,0,0,3,4,2,0,0,1,2,0,0,3,4,3,0,0,0,0,2,2,3,0,0,1,1,0,0,2,2,4,0,0,,,1,2,0,0,1,4,3,0,0,0,0,2,3,2,0,0,1,2,0,0,2,3,3,0,0,0,0,0,4,2,0,0,,,,,,,,",
 ",1,1,0,0,3,2,2,0,0,,,,,1,2,0,0,1,2,3,0,0,0,0,2,1,2,0,0,1,3,0,0,3,3,3,0,0,0,0,0,2,2,0,0,0,0,1,2,4,0,0,1,1,0,0,0,2,3,0,0,,,,1,2,0,0,1,3,4,0,0,0,0,2,2,3,0,0,1,2,0,0,0,3,3,0,0,0,0,3,4,4,0,0,,,,,1,2,0,0,2,3,4,0,0,0,0,1,4,5,0,0,1,1,0,0,0,4,4,0,0,,,,,,",
 ",,,,,,,,,,,1,1,0,0,1,3,3,0,0,1,2,0,0,0,3,2,0,0,0,0,3,4,3,0,0,1,1,0,0,3,4,4,0,0,,,,1,2,0,0,2,3,3,0,0,0,0,3,5,3,0,0,1,3,0,0,3,5,4,0,0,0,0,2,3,4,0,0,0,0,1,4,5,0,0,1,1,0,0,0,4,4,0,0,,1,1,0,0,1,5,3,0,0,1,3,0,0,2,4,3,0,0,0,0,1,5,4,0,0,0,0,0,5,2,0,0,1,2,0,0,0,5,3,0,0,0,0,2,4,4,0,0,,",
 ",,,,,,1,1,0,0,1,2,3,0,0,1,3,0,0,3,3,3,0,0,0,0,0,2,2,0,0,0,0,1,2,4,0,0,1,1,0,0,0,2,3,0,0,,,,1,2,0,0,2,2,3,0,0,0,0,3,4,3,0,0,1,2,0,0,3,4,4,0,0,0,0,1,3,5,0,0,1,1,0,0,0,3,4,0,0,,1,1,0,0,1,4,3,0,0,1,3,0,0,2,3,3,0,0,0,0,0,4,2,0,0,0,0,1,4,4,0,0,1,2,0,0,0,4,3,0,0,0,0,2,3,4,0,0,,,,,,,",
 
 -- test fp
 -- ",,,,,,,,,,,,1,2,0,0,1,3,4,0,0,0,0,3,4,3,0,0,1,1,0,0,0,3,3,0,0,,,,1,1,0,0,2,3,3,0,0,,,,,,,,"
}


atofp_params={"dcx","dcy","dir","trx","try","tcx","tcy"}
function atofp_new(s)
 -- s is a string containing 25 chunks
 -- if the chunk is empty, no room
 --
 -- chunk format:
 --  room_type,link_count,link_0...link_n
 --
 -- link_format:
 --  dcx,dcy,dir,trx,try,tcx,tcy
 local t,col,floor,i,x,y=split(s),{},{},1,1,1
 ?"tlen: "..#t
 while i<=#t do
  local cell,room_type={},t[i]
  i+=1 -- eat room type
  if room_type!="" then
   local link_count,links=tonum(t[i]),{}
   i+=1
   for n=0,link_count-1 do
    local link={}
    for idx=1,7 do
     local param,res=atofp_params[idx],t[i]
		   link[param]=res
		   i+=1
		  end
		  add(links,link)
   end
   cell={
    t=room_types[tonum(room_type)],
    links=links
   }
  end
  add(col,cell)
  x+=1
  if x==6 then
   add(floor,col)
   col={}
   x=1
   y+=1
  end
 end
 return floor
end

function precalc_doors()
 for pi,plan_str in ipairs(floor_plans) do
  local plan=atofp_new(plan_str)
  floor_plans[pi]=plan
	 for col in all(plan) do
	 for cell in all(col) do
		 for link in all(cell.links) do
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

rgen_corners={
 vec(18,18),
 vec(110,18),
 vec(18,110),
 vec(110,110),
}
function add_enemies_at_coords(r,cnt, fac)
 shuffle(rgen_corners)
 for i=1,cnt do
  local e=fac(rgen_corners[i])
  e.pos=v_sub(e.pos,v_div(e.s_size,2))
  e.init()
  add(r.enemies,e)
 end
end

function rgen_swarm(r)
 -- generates a handful of
 -- jumpers, 1 per corner
 -- can either be 3 or 4
 local cnt=3+flr(rnd(2))
 add_enemies_at_coords(r,cnt,e_jumper)
end

function rgen_walkers(r)
 local chance,cnt=rnd(),0
 if chance<0.5then cnt=1
 elseif chance<0.8then cnt=2
 else cnt=3 end
 add_enemies_at_coords(r,cnt,e_walker)
end

function rgen_walker_pets(r)
 local chance,cnt=rnd(),0
 if chance<0.75then cnt=1
 else cnt=2 end
 add_enemies_at_coords(r,cnt,e_walker)
 for i=#r.enemies,1,-1 do
  local owner=r.enemies[i]
  local e=e_jumper(
   v_add(owner.pos,v_mul(v_dir(owner.c_center,v_cntr),16)))
  e.init()
  add(r.enemies,e)
 end
end

function rgen_heavy(r)
 add_enemies_at_coords(r,1,e_heavy)
end

rgen_types={
 rgen_swarm,
 rgen_walkers,
 rgen_walker_pets,
 rgen_heavy,
}

function floor_from_plan(plan,first)
 local rooms,ends,floor={},{},{}
 for x,col in ipairs(plan) do
  local col_rooms={}
  for y,cell in ipairs(col) do
   local room={
    x=x,y=y,
    t=cell.t,
    links=cell.links,
    enemies={},
    items={},
    hearts={},
   }
   -- only add dead end room
   -- if its not the center room
   if cell.links and #cell.links==1 and not (x==3 and y==3) then
    add(ends,room)
   end
   if cell.t then
    add(rooms,room)
   end
   add(col_rooms,room)
  end
  add(floor,col_rooms)
 end
 
 -- select & update boss room
 setup_boss_room(floor, ends)
 
 -- pick random room for item room
 setup_item_room(rnd(ends))
 -- if this is the first floor
 -- then the center room is
 -- always an item room
 if first then
  setup_item_room(floor[3][3])
 end
 
 -- loop through rooms and add
 -- enemies
 for room in all(rooms) do
  if not room.boss and not room.item then
   rnd(rgen_types)(room)
  end
 end
 return floor
end

function setup_item_room(room)
 if room!=nil then
  room.item=true
  -- two items per item room
  -- center left & center right
  for i=0,1 do
   local item=next_item_chance()(vec(36+i*42,50))
	  item.init()
	  add(room.items,item)
  end
 end
end

function setup_boss_room(floor, ends)
 -- pick random room for boss
 -- room
 local boss_room=rnd(ends)
 boss_room.boss=true
 boss_room.boss_func=rnd(bosses)
 del(ends,boss_room)
end
-->8
-- items

function heart(pos)
 local h=entity(
  3,
  v_zero,
  vec(8,8),
  32,0,
  vec(8,8))
 h.pos=pos
 return h
end

function item_ent(pos,sx,sy)
 local item=entity(
  5,
  v_one,
  vec(11,11),
  sx,sy,
  vec(13,13))
 item.pos=pos
 item.c_active=false
 
 function item.acquire()
  add(ev_meter_start,item.on_meter_start)
  add(ev_meter_end,item.on_meter_end)
  add(ev_ply_hit,item.on_ply_hit)
  add(ev_enemy_hit,item.on_enemy_hit)
  add(ev_enemy_dead,item.on_enemy_dead)
 end
 
 return item
end

function i_rapid_fire(pos)
 local item=item_ent(pos,16,32)

 function item.on_meter_start()
  item.pres={}
  for source in all(sources) do
   local pre=source.delay
   source.delay=max(source.delay-2,2)
   add(item.pres,{source,pre-source.delay})
  end
 end
 
 function item.on_meter_end()
  for pre in all(item.pres) do
   pre[1].delay+=pre[2]
  end
 end
 
 return item
end

function i_extra_iframes(pos)
 local item=item_ent(pos,32,32)
 function item.on_ply_hit()
  ply.iframes*=1.5
 end
 return item
end

function i_add_source_on_meter(pos)
 local item=item_ent(pos,16,48)
 function item.on_meter_start()
  item.m_source=add_source()
 end
 function item.on_meter_end()
  if item.m_source then
   del_source(item.m_source)
  end
 end
 return item
end

function i_more_meter(pos)
 local item=item_ent(pos,32,48)
 function item.on_enemy_hit(arg)
  arg.meter_gain*=1.5
 end
 return item
end

function i_enemy_drop_chance(pos)
 local item=item_ent(pos,48,32)
 function item.on_enemy_dead(e)
  -- 2% chance for an item to drop
  if rnd()<0.02 then
   add_next_item(e.pos)
  end
 end
 return item
end

function i_more_hp(pos)
 local item=item_ent(pos,48,48)
 function item.acquire()
  max_health+=1
  ply.health+=1
 end
 return item
end

function i_add_seeker(pos)
 local item=item_ent(pos,64,32)
 function item.acquire()
  add_source(b_seeker,40,1,5)
 end
 return item
end

function i_shield(pos)
 local item=item_ent(pos,64,48)
 function item.on_meter_start()
  ply_eat_hit=true
 end
 function item.on_meter_end()
  ply_eat_hit=false
 end
 return item
end

function i_clear_buls(pos)
 local item=item_ent(pos,80,32)
 function item.on_meter_start()
  add_clear(v_cpy(ply.c_center))
 end
 return item
end

-- shuffle bag of all items
items={
 i_rapid_fire,
 i_extra_iframes,
 i_add_source_on_meter,
 i_more_meter,
 i_enemy_drop_chance,
}
items.idx=1
shuffle(items)

rare_items={
 i_more_hp,
 i_add_seeker,
 i_shield,
 i_clear_buls,
}
rare_items.idx=1
shuffle(rare_items)

function next_bag(bag)
 local item=bag[bag.idx]
 bag.idx+=1
 if bag.idx>#bag then
  bag.idx=1
  shuffle(bag)
 end
 return item
end

function next_item()
 return next_bag(items)
end

function next_rare_item()
 return next_bag(rare_items)
end

function next_item_chance()
 if rnd()<0.1 then
  return next_rare_item()
 end
 return next_item()
end
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
 
 local base_upd_spr=e.upd_spr
 function e.upd_spr()
  if e.s_center.x<ply.s_center.x then
   e.s_dir_idx=1
  else
   e.s_dir_idx=2
  end
  base_upd_spr()
 end

 function e.dmg(n,dir,knock)
  e.health-=n
  dir=dir or v_dir(ply.c_center,e.c_center)
  knock=2
  e.knock=v_mul(dir,knock)
 	return e.health>0
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

function e_walker(pos)
 local e=enemy(
  pos,
  6,
  vec(1.5,1.5),
  vec(13,13),
  vec(56,16),
  vec(16,16),
  30) -- health

 e.spd=0.25
 
 function e.update()
  if e.near(ply) and not v_eq(e.pos,ply.pos) then
	  e.vel=v_mul(v_dir(e.pos,ply.pos),e.spd)
	 end
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
  4,
  vec(2,2),
  vec(4,4),
  -- spr can be either 5 or 6
  vec(8*(5+flr(rnd())),0),
  vec(8,8),
  12) -- health

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
    local dir=v_dir(e.c_center,v_cntr)
    local perp_dir=v_perp(dir)
    e.dir=v_lerp(perp_dir,dir,rnd())
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
  6,
  vec(4,4),
  vec(7,8),
  -- spr can be either 5 or 6
  vec(56,0),
  vec(16,16),
  60) -- health
 
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
 e.shot_arc=0.1
 e.shot_count=4
 e.shot_start_radius=8
 e.shot_life=24
 e.shot_spd=2
 
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
 
 return e
end

function lerp(a,b,t)
	return a+(b-a)*t
end

function e_boss_lilguy(pos)
 local e=enemy(
  pos,
  7,
  vec(1.5,1.5),
  vec(13,13),
  -- spr can be either 5 or 6
  vec(88,16),
  vec(16,16),
  200+70*floors_cleared) -- health
 
 e.maxhp=e.health
 
 e.phase=0
 e.starting_phase=false
 e.p2_buls={}

 -- lilguy
 -- left-right movement
 e.bound_l=8
 e.bound_r=104
 e.tx_time_min=12
 e.tx_time_max=120
 -- firing
 e.shot_arc=0.3
 e.shot_count=3
 e.shot_start_radius=1
 e.shot_life=0
 e.shot_spd=1
 e.shot_fac=b_multi
 e.shoot_timer=80
 e.shoot_time=90
 
 e.spread_timer=-1
 e.spread_time=30
 
 e.last_tx=e.pos.x
 e.next_tx=rnd(e.bound_r-e.bound_l)+e.bound_l
 e.tx_time=flr(rnd(e.tx_time_max-e.tx_time_min)+e.tx_time_min)
 e.tx_timer=e.tx_time
 
 function e.try_shoot()
  e.shoot_timer-=1
  if e.shoot_timer==0 then
   e.shoot_ply()
   e.shoot_timer=e.shoot_time
  end
  
  if e.spread_timer>-1 then
   e.spread_timer-=1
   if e.spread_timer%4==0 then
   	local t=1-e.spread_timer/e.spread_time
    local right_ang=lerp(1,0.8,t)
    local left_ang=lerp(0.5,0.7,t)
    e.spawn_spread_linear(right_ang)
    e.spawn_spread_linear(left_ang)
    sfx_shoot_seek.play()
   end
  end
 end
 
 function e.phase1()
  local x=lerp(
	   e.next_tx,
	   e.last_tx,
	   e.tx_timer/e.tx_time)
  e.pos.x=x
  e.tx_timer-=1
	 if e.tx_timer==0 then
   e.last_tx=e.next_tx
   e.next_tx=rnd(e.bound_r-e.bound_l)+e.bound_l
   e.tx_time=flr(rnd(e.tx_time_max-e.tx_time_min)+e.tx_time_min)
   e.tx_timer=e.tx_time
  end
  e.try_shoot()
 end
 
 function e.update()
  if e.phase==0 then
   e.phase1()
  else
   -- circ fade to black then
   -- clear all bullets
   if e.starting_phase then
    e.tx_timer-=1.5
    if e.tx_timer==0 then
     ply.pos=vec(60,92)
     e.pos.x=56
     bullets={}
     e.starting_phase=false
    end
   elseif e.tx_timer<e.tx_time then
    e.tx_timer+=1.5
    -- hack: force player pos
    -- and bullets clear until
    -- circ fade is done
    e.pos.x=56
    bullets={}
   else
    e.try_shoot()
   end
  end
  
  e.upd_coords()
  e.upd_spr()
	 if e.aabb(ply) then
	  dmg_ply()
	 end
 end
 
 local base_draw=e.draw
 function e.draw()
  base_draw()
  if e.phase>0 and e.tx_timer!=e.tx_time then
   circ_fade(e.c_center,e.tx_timer/e.tx_time)
  end
  -- boss health bar
  -- todo: make this a baseclass
  --  for other bosses
  local hpfrac=e.health/e.maxhp
  -- hp bar border
  rectfill(3,3,128-3,7,0)
  rect(3,3,128-3,7,7)
  -- hp bar fill
  local left=5
  local right=128-5
  local x=lerp(left,right,hpfrac)
  line(left,5,x,5,7)
  -- hp bar sections (phases)
  x=lerp(left,right,0.66)
  pset(x,5,0)
  x=lerp(left,right,0.33)
  pset(x,5,0)
 end
 
 function e.next_phase()
  e.phase+=1
  e.tx_time=e.tx_time_max
  e.tx_timer=e.tx_time
  e.starting_phase=true
  e.shoot_timer=1
 end
 
 function e.spawn_spread_linear(ang)
  local b=b_linear(
   v_cpy(e.s_center),
   v_polar(1,ang),
   t_enemy)
  b.destruct_mode=2
  b.init()
  add(bullets,b)
 end
 
 function e.boss_shoot_multi()
  local b=b_multi(
   v_cpy(e.s_center),
   v_cpy(v_zero),
   t_enemy,
   e.shot_life)
  
  b.include{
   multi_cnt=8,
   multi_ang=0.1*time(),
   multi_rot_spd=1/15,
   multi_base_spd=1/15,
   multi_rad_spd=0.25,
   del_on_dmg=false,
  }
  b.init()
  add(bullets,b)
 end
 
 function e.boss_shoot_spread()
  e.spread_timer=e.spread_time
 end
 
 local base_shoot_ply=e.shoot_ply
 function e.shoot_ply()
  if e.phase==0 then
   if rnd()<0.2 then
    e.boss_shoot_spread()
   else
    base_shoot_ply()
   end
  elseif e.phase==1 then
   e.boss_shoot_multi()
  elseif e.phase==2 then
   if rnd()<0.2 then
    e.boss_shoot_spread()
   else
    base_shoot_ply()
   end
   e.boss_shoot_multi()
  end
 end
 
 local base_dmg=e.dmg
 function e.dmg(n)
  if e.starting_phase then
   -- take no damage while
   -- starting the next phase
   return e.health>0
  end

  local prehp=e.health
  if e.health>0.66*e.maxhp then
   base_dmg(n)
   if e.health<=0.66*e.maxhp then
    e.next_phase()
   end
   return e.health>0
  elseif e.health>0.33*e.maxhp then
   base_dmg(n)
   if e.health<=0.33*e.maxhp then
    e.next_phase()
   end
   return e.health>0
  end
  return base_dmg(n)
 end
 
 return e
end

function shoot_multi(pos,dir,arc,n,r,lt,spd,b_fac)
 b_fac=b_fac or b_linear
 dir=v_rot(dir,-arc/2)
 local bul_arc=arc/(n+1)
 for i=1,n do
  dir=v_rot(dir,bul_arc)
  local bpos=v_add(pos,v_mul(dir,r))
  local bullet=b_fac(
   pos,
   v_mul(dir,spd),
   t_enemy,
   lt)
  bullet.init()
  bullet.destruct_mode=2
  add(bullets,bullet)
 end
end

bosses={
 e_boss_lilguy,
}
-->8
-- sfx

function single_sfx(id,len)
 return {
  play=function()
   sfx(id,-1,0,len)
  end
 }
end

function hitstun_sfx(before,
                     after)
 return {
  play=function()
   before.play()
   add(hitstun_awaiters,after.play)
  end
 }
end

function track(pat,fade,chan)
 return {
  play=function()
   music(pat,fade,chan)
  end
 }
end

sfx_menu_hi=single_sfx(0)
sfx_menu_sel=single_sfx(1)
sfx_menu_back=single_sfx(2)
sfx_door_enter=single_sfx(3)
sfx_door_exit=single_sfx(4)
sfx_shoot=single_sfx(5)
sfx_shoot_seek=single_sfx(6)
sfx_ply_walk=single_sfx(8)
sfx_ply_dmg=hitstun_sfx(
 single_sfx(5,2),
 single_sfx(7))

-- todo: this, but for track
-- 2 as well
sfx_ply_dmg_last=hitstun_sfx(
 single_sfx(5),
 track(1,0,3))

music_loop1=track(0,300,3)
music_loop2=track(3,300,3)
music_boss_loop=track(4,300,3)

-->8
-- states: boss room

boss_fade_time=64

function state_boss_room_enter()
 state_timer=boss_fade_time
 state_next=state_boss_room_enter_2

 state_update=state_timer_update
 state_draw=boss_enter_fadeout_draw
end

function state_boss_room_enter_2()
 state_timer=boss_fade_time
 state_next=state_normal

 -- state_update should already be
 -- state_timer_update, so no need
 -- to set here.
 state_draw=boss_enter_fadein_draw
 
 room=next_room
 
 boss=room.boss_func(vec(56,16))
 add(room.enemies,boss)
 boss.init()
	ply.pos=vec(60,92)
	ply.upd_coords()
end

-- just use a timer to update
-- to the next state
function state_timer_update()
 if state_timer>0 then
  state_timer-=1
 end
 if state_next and state_timer==0 then
  state_next()
 end
end

fade_map={0,1,2,5,7}
function boss_enter_fadeout_draw()

 -- local idx=flr(0.5+5*state_timer/boss_fade_time)
 
 -- door blips play at:
 -- 128, 96, 64, 32
 local idx=1+flr(4*(state_timer-1)/boss_fade_time)
 pal(7,fade_map[idx])
 draw_normal()
 print(idx)
 pal(7,7)
end

function circ_fade(pos,frac)
 poke(0x5f34, 0x2)
 local r=128*frac
 circfill(pos.x,pos.y,r,0x1800)
 poke(0x5f34, 0x0)
 circ(pos.x,pos.y,r,7)
end

function boss_enter_fadein_draw()
 cls()
 draw_boss_room()
 draw_all(enemies)
 ply.draw()
 draw_ply_hud()
 circ_fade(
  ply.s_center,
  (boss_fade_time-state_timer)/boss_fade_time)
end
-->8
-- states: floor transition

floor_fade_time=60

function state_floor_end()
 state_timer=floor_fade_time
 state_next=state_floor_begin

 state_update=state_timer_update
 state_draw=state_floor_end_draw
end

function state_floor_begin()
 state_timer=floor_fade_time
 state_next=state_normal

 -- state_update should already be
 -- state_timer_update, so no need
 -- to set here.
 state_draw=state_floor_begin_draw
 setup_next_floor()
end

function state_floor_end_draw()
 poke(0x5f34, 0x2)
 local r=128*(state_timer-1)/boss_fade_time
 circfill(ply.s_center.x,ply.s_center.y,r,0x1800)
 poke(0x5f34, 0x0)
 circ(ply.s_center.x,ply.s_center.y,r,7)
end

function state_floor_begin_draw()
 cls()
 room.t.draw()
 draw_doors()
 draw_all(enemies)
 ply.draw()
 draw_ply_hud()
 poke(0x5f34, 0x2)
 local r=128*(boss_fade_time-state_timer)/boss_fade_time
 circfill(ply.s_center.x,ply.s_center.y,r,0x1800)
 poke(0x5f34, 0x0)
 circ(ply.s_center.x,ply.s_center.y,r,7)
end
-->8
-- states: dead

dead_fade_time=150

function state_dead()
 state_timer=dead_fade_time
 state_next=nil
 state_update=update_dead
 state_draw=draw_dead
end

function update_dead()
 if btnp(➡️) or btnp(⬅️) then
  menu_idx=menu_idx==1 and 2 or 1
  sfx_menu_hi.play()
 end
 
 if menu_noquit_counter>0 then
  menu_noquit_counter-=1
 end
 
 if btnp(🅾️) and menu_idx==2 then
  menu_noquit_counter=150
  sfx_menu_back.play()
 end
 
 if btnp(🅾️) and menu_idx==1 then
  load("game.p8")
  sfx_menu_sel.play()
 end
 
 state_timer_update()
end

function draw_dead()
 cls()

 local idx=ceil(5*(1-state_timer/dead_fade_time))
 pal(7,fade_map[idx])
 ?"⧗ "..time_minutes..":"..flr(time_seconds*10)/10,33,12,7
 ?"🐱 "..enemies_killed,80,12
 ?"⌂ "..rooms_cleared,33,18
 ?"▒ "..floors_cleared,80,18

 ?"YOU ARE DEAD,",38,46
 ?"NOT BIG SURPRISE",32,52
 
 -- centered on thirds 43, 85
 ?"start",33,82
 ?"again",33,88
 ?"quit",92,85
 
 if menu_idx==1 then
  ?"🅾️",33-9,85
 else
  ?"🅾️",92-9,85
 end
 
 if menu_noquit_counter>0 then
  ?"you cant go...",38,64
 end

 pal(7,7)
end
__gfx__
66666666666776666666777667776666677667766666666676666667667666666666676666666666666666666666666666666666666666666666666666666666
66666666667007666667000777077666700770076776677667766776667760666606776666666777776666666666667777666666666667777766666667666676
66766766667007666770007670707666700000076677776666777766667706666660776666677777777766666666777777776666666777777777666670766707
66677666670000767000707677077666700000076707707667777076666077666677066666777777777776666667777777776666667777777777766670077007
66677666700770077000707667776666700000076677776666707766660677777777606666777777777776666667777777777666667777777777766670777707
66766766700000076770007666666666670000767767767777677677666677077077666666777700707776666667707777777666667777777777766667077076
66666666707777076667000766666666667007667667766776677667667707700770776666770000000776666667000777777666667777777777766666766766
66666666676666766666777666666666666776666676676666766766666700777700766666677700777776666670770077777666666777777777766666666666
77777777000000000000000066600000000006660000007766660000666677777777666666670000000766666667000077776666666777777777666666766766
77777777000000000000000066077700007770660000000766007777667777777777776666667000007666666666770007766666666670777076666667766776
77777777000000000000070060777700007777060770000060777707677767707776777666670770770766666666667777666666666700000007666667077076
77777777000000000000700060707000000707060777777707707777777666770766677766700007000076666666677007766666667000000000766667777776
77777777000000000007000007777000000777700770777707777777776667707776667766700000000076666666670700766666667000000000766667077076
77777777000000000070000007777000000777706077770707700000776677777777667766677700077766666666677077766666666777000777666666766766
77777777000000000000000007077007700770706600777700000007666677766777666666670070700766666666700700076666666700777007666666666666
77777777000000000000000007777077770777706666000000000077666677666677666666667767677666666666677677766666666677666776666666666666
66677666666667767776666666666666666666666660000000000666666666777766666666666666667666666666666666666666666666666666666667766666
66700766666670077007666666666666666666666607770000777066666667000076666666666666676677666666677777666666666666666666666670076666
66700766677700767000777666666666666666666077700000077706666670000076666666666777666666766666777777776666666666666666666670076666
66700766700000076700000766667777777766666077707007077706666700000076666666667007777666666667770777777666666666666666666667766666
67000076700000076670007766770000000077660770700000070770666707000007666666670007770767666667770077777666666666666666666666666666
70000007677700766670076667000000000000760777770000777770667077700700776666670000700766766667000000070766666666666666666666666666
70700707666670076670766670000000000000070707770770777070667070700770007666670700000766666677770007077776666776666667766666666666
67677676666667766667766670000000000000070777777777777770667070700070007666670007070766666700000077076776666707666670766666666666
66676666666666667776666670000000000000070000007766660000670007700077700766670077000766666777777000076766666700766700766667766776
66707666666777777007766670000000000000070007000766007777670000007000000766667077707666666666700000766666666670077007666677777777
66707666677000767000076667000000000000760700077760777707700000007700000766670777770766666667077077076666666670000007666677777777
67000766700007666700007666770000000077660777777707770777700000077770000766770070700776666677000700077666666667000076666677777777
67000766677000766700776666667777777766660777077707777777700000077700000767070707070707666707700000770766666667000076666677777777
67070766666777776670766666666666666666666077770707000777670077000007700766777777777776666677777777777666666666700766666667777776
67767766666666666667666666666666666666666600777700070007667766770076677666670076700766666667007770076666666666700766666666777766
67666766666666666666666666666666666666666666000000000077666666667766666666667766677666666666776667766666666666677666666666677666
66600000000006666677777777766666667777777776666666777777777666666677777777766666667777777776666666666666666666666666666666666666
66077770077770666700000000076666670000000007666667000000000766666700000000076666670000000007666666666666666666666666666666666666
60777707707777067000000000007666700700000000766670070007070076667000000000007666700070007000766666666666666666666666666666666666
60777700007777067000007007007666707770000000766670070007070076667000077700007666700700000700766666666666666666666666666666666666
07707077770707707000070070007666700700777700766670070007070076667000700070007666707000000070766666666666666666666666666666666666
07777077070777707000700700007666700007000070766670077707770076667007000007007666700007070000766666666666666666666666666666666666
07077000000770707007007007007666700007077070766670000000000076667007000007007666700000700000766666666666666666666666666666666666
07777777777777707000070070007666700007077070766670077707070076667007000007007666700007070000766666666666666666666666666666666666
00707707666600007000700700007666700007000070766670070007700076667000700070007666707000000070766666666666666666666666666666666666
07007707660077777007007000007666700000700700766670070007070076667000077700007666700700000700766666666666666666666666666666666666
07770007607777077000000000007666700000077000766670077707070076667000000000007666700070007000766666666666666666666666666666666666
07777777077707776700000000076666670000000007666667000000000766666700000000076666670000000007666666666666666666666666666666666666
07770777077777776677777777766666667777777776666666777777777666666677777777766666667777777776666666666666666666666666666666666666
60777707077700076666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66007777070077076666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66660000007070076666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
67777777777777766677777777766666667777777776666666777777777666666677777777766666666666666666666666666666666666666666666666666666
70000000000000076700000000076666670000000007666667000000000766666700000000076666666666666666666666666666666666666666666666666666
70007000000000077007700000007666700070007000766670000000000076667000700070007666666666666666666666666666666666666666666666666666
70077700000000077070070070007666700077077000766670000770770076667007777777007666666666666666666666666666666666666666666666666666
70707070000000077070070770007666700070707000766670007007007076667070000000707666666666666666666666666666666666666666666666666666
70007000000000077007700070007666700070007000766670007000007076667070777770707666666666666666666666666666666666666666666666666666
70000000000000077000000070007666700070007000766670007000007076667070777770707666666666666666666666666666666666666666666666666666
67777777777777767000700070007666700000000000766670000700070076667070077700707666666666666666666666666666666666666666666666666666
67777777777777767007770070007666700070007000766670070070700076667007007007007666666666666666666666666666666666666666666666666666
70000000000000077000700070007666700777077700766670777007000076667000700070007666666666666666666666666666666666666666666666666666
70000000000000077000000777007666700070007000766670070000000076667000077700007666666666666666666666666666666666666666666666666666
70000000000000076700000000076666670000000007666667000000000766666700000000076666666666666666666666666666666666666666666666666666
70000000000000076677777777766666667777777776666666777777777666666677777777766666666666666666666666666666666666666666666666666666
70777777777777076666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
70000000000000076666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
67777777777777766666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
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
0004000034055370553c0550000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000200003705032050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020800002e650006000060000600236400060000600006001c6200060000600006000f61000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
020800001d660196602c6502c6502c6502c6402c6302c6202c6100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020500003b6203d620306100060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000000000000000000000000000000000000000000000000000000000
020500003d62030620306100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02050000290453f630290453f620290453f610220053f600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020800002b64009600026000000026630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0205000036610396303b6403d6403d6403d6403c6403b6403a640386403664033630306302d6302863024630206301b63015630106200b6200862005620026200061000610006100061000000000000000000000
001e00002204522715260452671529045297152d0452d7152e0452e7152d0452d71529045297152604526715240452471528045287152b0452b7152f0452f71530045307152f0452f7152b0452b7152804528715
001e00000a1100a1110a1110a1110a1110a1110a1110a1110a1110a1110a1110a1110a1110a11111111111110c1110c1110c1110c1110c1110c1110c1110c1110c1110c1110c1110c1110c1110c1110511105111
001e00000203300003000030203302633006130000300003000030c0330c03302033026330203300003000030203300003000030203302633006130000300003000030c0330c0330203302633020330263300613
001e00002004520715240452471527045277152b0452b7152c0452c7152b0452b7152704527715240452471520045207152071520715000050000500005000052004520715207152071500005000050000500005
001e00000f1100f1110f1110f1110f1110f1110f1110f1110f1110f1110f1110f1110f1110f1110f1110f1110c1110c1110c1110c1110c1110c1110c1110c1110c11500000000000000000000000000000000000
001e00000203300003000030203302633006130000300003000030c0330c033020330263302033026330061302033000130001300013000030000300003000030000300003000030000300003000030000300003
001e00002c0452c7152b0452b71527045277152404524715220452271524045247152704527715240452471520045207152071520715000050000500005000052004520715207152071500005000050000500005
001e00002204422714227142271400004220141d7141d71422044227142271422714000040000400004000042404424714247142471400004240141f7141f7142404424714247142471400004000040000400004
301e00002654426514265142651400004295142651422514265442651426514265140000400004000040000428544285142851428514000042b51428514245142854428514285142851400004000040000400004
921e00000061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610006100061000610
001000001f0302003000000240300000027030000002b0302c030000002c0302b03000000270302403000000200302203000000260300000029030000002d0302e030000002e0302d03000000290302603000000
001000000f12514125181251b1251812514125181251b1251812514125181251b1251812514125181251b12511125161251a1251d1251a125161251a1251d1251a125161251a1251d1251a125161251a1251d125
011000000d6130d043000030d0430d0430d6430d613000030d043000030d043000030d0430d6430d04300003000030d04300003000030d0430d6430d613000030d043000030d043000030d0430d6430d0430d643
03050000210453d630290453b62000000396100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
03 0a0b0c44
04 100e0f44
04 0d0e0f44
03 11121344
03 14151644
00 40424344

