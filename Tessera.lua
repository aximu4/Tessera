term.setCursorBlink(false)local tx,tu,sp,fs,os,rs,kr,ev=term,textutils,peripheral,fs,os,redstone,keys,os.pullEvent
local function sz()local w,h=tx.getSize()return w,h end
local W,H=sz()
local P=tx.current()
local B={window.create(P,1,1,W,H,false),window.create(P,1,1,W,H,false)};local bi=1;local function rdr(w)tx.redirect(w)end;rdr(B[1])
local function clr(c,b)if c then tx.setTextColor(c)end;if b then tx.setBackgroundColor(b)end;tx.clear() end
local function mv(x,y)tx.setCursorPos(x,y)end
local function pr(s)tx.write(s)end
local function sw()B[bi].setVisible(true)B[3-bi].setVisible(false)B[bi].redraw()rdr(B[3-bi])B[3-bi].setCursorPos(1,1)bi=3-bi end
local RND=math.random math.randomseed(os.time()+math.floor(os.clock()*1000))
local dir="Tessera"local fset=dir.."/settings.dat"local fldb=dir.."/leader.dat"
if not fs.exists(dir)then fs.makeDir(dir)end
local function FEx(p)return fs.exists(p)end
local function L(p)local f=fs.open(p,"r")if not f then return nil end;local d=f.readAll()f.close()return d end
local function S(p,d)local f=fs.open(p,"w")if not f then return end;f.write(d)f.close()end
local function SL(p,t)S(p,tu.serialize(t))end
local function LL(p)local d=L(p)if not d then return nil end;return tu.unserialize(d)end
local DEF={musicVol=80,startLvl=1,name="YOU",rebind={left=kr.left,right=kr.right,down=kr.down,drop=kr.space,rotR=string.byte("x"),rotL=string.byte("z"),rot180=string.byte("c"),hold=kr.leftShift,pause=kr.p,exit=kr.q}}
local function loadSet()local t=LL(fset)if not t then t=DEF end;for k,v in pairs(DEF)do if t[k]==nil then t[k]=v end end;for k,v in pairs(DEF.rebind)do if not t.rebind[k]then t.rebind[k]=v end end;return t end
local function saveSet(t)SL(fset,t)end
local function loadLB()local t=LL(fldb)if not t then t={}end;return t end
local function saveLB(t)SL(fldb,t)end
local function pushLB(n,sc,l,ln)local t=loadLB()t[#t+1]={n=n,s=sc,l=l,ln=ln,d=os.date("%Y-%m-%d")}table.sort(t,function(a,b)return a.s>b.s end)if #t>100 then for i=#t,101,-1 do t[i]=nil end end;saveLB(t)end
local function box(x,y,w,h,c1,c2)local xx,yy;for i=0,h-1 do mv(x,y+i)tx.setBackgroundColor(i==0 or i==h-1 and c1 or c2)tx.setTextColor(c1)pr(string.rep(" ",w))end end
local function cen(y,s)mv(math.floor((W-#s)/2)+1,y)pr(s)end
local spk=sp.find("speaker")and sp.wrap(sp.find("speaker"))or nil
local NBSi={"harp","bd","snare","hat","bass","flute","bell","guitar","chime","xylophone","iron_xylophone","cow_bell","didgeridoo","bit","banjo","pling"}
local NBSsnd={}for i,v in ipairs(NBSi)do NBSsnd[i]="minecraft:block.note_block."..v end
local function pitchFromKey(k)return 2^((k-45)/12)end
local function NBSload(p)local f=fs.open(p,"rb")if not f then return nil,"no file" end
local function rdU16()local a=f.read()local b=f.read()if not a or not b then return nil end;return a+b*256 end
local function rdU32()local a=rdU16()local b=rdU16()if not a or not b then return nil end;return a+b*65536 end
local function rdsz(n)local s=f.read(n)return s end
local function rds()local n=rdU32()if not n then return nil end;local s=rdsz(n)or""return s end
local lyrs=rdU16()or 0;local length=rdU16()or 0;local title=rds()or""local auth=rds()or""local org=rds()or""local desc=rds()or"";local tempo=rdU16()or 100;local tps=tempo/100;f.read(23)
local events={}local tick=0 while true do local d=rdU16()if not d then break end;if d==0 then break end;tick=tick+d;local layer=0;while true do local dl=rdU16()if not dl then break end;if dl==0 then break end;layer=layer+dl;local inst=f.read()or 0;local key=f.read()or 45;f.read()f.read()local vol=f.read()or 100;f.read()if not events[tick]then events[tick]={}end;events[tick][#events[tick]+1]={i=inst+1,k=key,v=vol/100}end end
f.close()return{tps=tps,ev=events,len=tick}end
local function NBSplay(song,vol,stopSig)if not spk or not song then return function()end,function()end end;local alive=true;local paused=false;local volm=(vol or 100)/100
local function stopper()alive=false end
local function pause(v)paused=v and true or false end
local co=coroutine.create(function()local t0=os.clock()local t=0 while alive do if paused then os.sleep(0.05)else local e=song.ev[math.floor(t+0.5)]if e then for _,n in ipairs(e)do local snd=NBSsnd[n.i]or NBSsnd[1]spk.playSound(snd,volm*n.v,pitchFromKey(n.k))end end;t=t+song.tps;local dt=(os.clock()-t0) if dt<t/20 then os.sleep((t/20-dt)) end;if t>song.len+20 then break end end end end)
local function run()if coroutine.status(co)~="dead"then local ok,er=coroutine.resume(co)if not ok then end end end
local function api(cmd,...)if cmd=="stop"then stopper()elseif cmd=="pause"then pause(...)end end
return run,api end
local musMenu="Tessera/score.nbs"local musPool={"Tessera/music-a.nbs","Tessera/music-b.nbs","Tessera/music-c.nbs"}
local mrun,mctl=nil,nil
local function playFile(p,vol)local s,er=NBSload(p)if not s then return end;mrun,mctl=NBSplay(s,vol)end
local function musicTick()if mrun then mrun()end end
local function musicStop()if mctl then mctl("stop")mrun,mctl=nil,nil end end
local function musicMenu(vol)musicStop()if FEx(musMenu)then playFile(musMenu,vol)end end
local function musicGame(vol)musicStop()local c={}for _,v in ipairs(musPool)do if FEx(v)then c[#c+1]=v end end;if #c>0 then playFile(c[RND(#c)],vol)end end
local Pcs={{{0,1,0,0,1,1,1,0},{0,1,0,0,0,1,0,0},{0,1,1,1,0,0,1,0},{0,0,1,0,1,1,1,0}},{{1,1,0,0,0,1,1,0},{0,0,1,1,1,1,0,0}},{{0,1,1,0,1,1,0,0},{1,0,0,0,1,1,0,0}},{{1,1,1,1}},{{0,1,0,0,1,1,0,0},{0,1,0,0,0,1,1,0},{0,1,1,0,0,0,1,0},{1,1,0,0,1,0,0,0}},{{1,1,1,0,0,1,0,0},{0,1,0,0,1,1,0,0},{0,1,0,0,0,1,0,0},{0,1,0,0,0,1,1,0}},{{1,1,0,0,0,1,0,0},{0,1,0,0,1,1,0,0},{0,1,0,0,1,0,1,0},{1,1,0,0,1,0,0,0}}}
local Col={colors.cyan,colors.yellow,colors.red,colors.blue,colors.orange,colors.green,colors.purple}
local Fw,Fh=10,20
local function mkM(w,h)local t={}for y=1,h do t[y]={}for x=1,w do t[y][x]=0 end end;return t end
local function cpy(t)local n={}for i=1,#t do n[i]={table.unpack(t[i])}end;return n end
local function rot(m)local w,h=4,2 while #m>0 and #m%4~=0 do m[#m+1]=0 end;w,h=4,math.ceil(#m/4)local g={}for y=1,h do for x=1,w do g[(x-1)*h+y]=m[(h-y)*w+x]or 0 end end;return g end
local function wof(m)local w=0;for i=1,#m do if i%4==0 then end end;return 4 end
local function dim(m)local w=4;local h=math.ceil(#m/4)return w,h end
local function coll(grid,px,py,sh)local w,h=4,math.ceil(#sh/4)for y=1,h do for x=1,4 do local v=sh[(y-1)*4+x]if v==1 then local gx,gy=px+x-1,py+y-1 if gx<1 or gx>Fw or gy>Fh or (gy>=1 and grid[gy][gx]~=0)then return true end end end end;return false end
local function lock(grid,px,py,sh,ci)local h=math.ceil(#sh/4)for y=1,h do for x=1,4 do if sh[(y-1)*4+x]==1 then local gx,gy=px+x-1,py+y-1 if gy>=1 and gy<=Fh and gx>=1 and gx<=Fw then grid[gy][gx]=ci end end end end end
local function clrLines(grid)local n=0 for y=Fh,1,-1 do local ok=true for x=1,Fw do if grid[y][x]==0 then ok=false break end end;if ok then table.remove(grid,y)table.insert(grid,1,({}) )for x=1,Fw do grid[1][x]=0 end;n=n+1;y=y+1 end end;return n end
local function newBag()local b={1,2,3,4,5,6,7}for i=#b,2,-1 do local j=RND(i)b[i],b[j]=b[j],b[i]end;return b end
local function drawGrid(grid,ox,oy,cur,px,py,sh,ci)for y=1,Fh do mv(ox,oy+y-1)for x=1,Fw do local c=grid[y][x]local ch=" "local bg=colors.black;if c~=0 then bg=Col[c]end;tx.setBackgroundColor(bg)pr(" ")end end
if sh then local h=math.ceil(#sh/4)for y=1,h do for x=1,4 do if sh[(y-1)*4+x]==1 then local gx,gy=px+x-1,py+y-1 if gy>=1 and gy<=Fh and gx>=1 and gx<=Fw then mv(ox+gx-1,oy+gy-1)tx.setBackgroundColor(Col[ci])pr(" ")end end end end end end
local function drawUI(sc,l,ln,nm,vol,hl,hnl,holdPiece,ox,oy)tx.setTextColor(colors.white)tx.setBackgroundColor(colors.black)mv(ox+Fw+2,oy)pr("SCORE: "..sc)mv(ox+Fw+2,oy+1)pr("LEVEL: "..l)mv(ox+Fw+2,oy+2)pr("LINES: "..ln)mv(ox+Fw+2,oy+3)pr("VOL: "..vol.."%")mv(ox+Fw+2,oy+5)pr("NEXT:")for i=1,math.min(5,#hl)do local id=hl[i]tx.setBackgroundColor(Col[id])mv(ox+Fw+2,oy+5+i)pr("    ")end;tx.setBackgroundColor(colors.black)mv(ox-1,oy-1)pr("+"..string.rep("-",Fw).."+")for y=0,Fh-1 do mv(ox-1,oy+y)pr("|")mv(ox+Fw,oy+y)pr("|")end;mv(ox-1,oy+Fh)pr("+"..string.rep("-",Fw).."+")mv(ox+Fw+2,oy+12)pr("HOLD:")tx.setBackgroundColor(holdPiece and Col[holdPiece]or colors.gray)mv(ox+Fw+2,oy+13)pr("    ")tx.setBackgroundColor(colors.black)end
local function scoreFor(c,lvl)local t={0,40,100,300,1200}return (t[c]or 0)*(lvl)end
local function gameLoop(st)
local vol=st.musicVol or 80
musicGame(vol)
local grid=mkM(Fw,Fh)local bag=newBag()local nxt={}for i=1,5 do if #bag==0 then bag=newBag()end;nxt[#nxt+1]=table.remove(bag,1)end
local hold=nil;local canHold=true
local function popNext()if #bag==0 then bag=newBag()end;local id=table.remove(bag,1)nxt[#nxt+1]=table.remove(bag,1)or newBag()[1]local n=nxt[1]table.remove(nxt,1)return id end
local cur=popNext()local rotI=1;local shp=Pcs[cur][rotI]local px,py=4,0;local sc=0;local ln=0;local lvl=math.max(1,st.startLvl or 1);local dropT=0;local gInt=math.max(0.05,0.6-(lvl-1)*0.05);local fallTimer=os.startTimer(gInt);local ox,oy=3,2;local running=true;local paused=false
local rb=st.rebind
local function spawn()cur=popNext()rotI=1;shp=Pcs[cur][rotI]px,py=4,0;canHold=true;if coll(grid,px,py,shp)then return false end;return true end
local function rotCW()local nr=rotI%#Pcs[cur]+1 local ns=Pcs[cur][nr]if not coll(grid,px,py,ns)then rotI=nr;shp=ns end end
local function rotCCW()local nr=(rotI-2)%#Pcs[cur]+1 local ns=Pcs[cur][nr]if not coll(grid,px,py,ns)then rotI=nr;shp=ns end end
local function rot180()local nr=(rotI+1)%#Pcs[cur]+1 local ns=Pcs[cur][nr]if not coll(grid,px,py,ns)then rotI=nr;shp=ns end end
local function holdSwap()if not canHold then return end;canHold=false;if not hold then hold=cur;spawn()else local t=hold;hold=cur;cur=t;rotI=1;shp=Pcs[cur][1];px,py=4,0 end end
local function hardDrop()local y=py while not coll(grid,px,y+1,shp)do y=y+1 end;py=y end
local function stepDown()if not coll(grid,px,py+1,shp)then py=py+1 else lock(grid,px,py,shp,cur)local c=clrLines(grid)if c>0 then sc=sc+scoreFor(c,lvl)ln=ln+c;if ln//10+1>lvl then lvl=ln//10+1;gInt=math.max(0.05,0.6-(lvl-1)*0.05)end end;if not spawn()then running=false end end;fallTimer=os.startTimer(gInt)end
local function move(dx)if not coll(grid,px+dx,py,shp)then px=px+dx end end
local function drawAll()clr(nil,colors.black)drawGrid(grid,ox,oy,cur,px,py,shp,cur)drawUI(sc,lvl,ln,st.name or "YOU",vol,nxt,5,hold,ox,oy)sw()end
drawAll()
while running do local e={ev()}if e[1]=="timer"and e[2]==fallTimer then stepDown()drawAll()
elseif e[1]=="key"then local k=e[2]if k==rb.left then move(-1)drawAll()
elseif k==rb.right then move(1)drawAll()
elseif k==rb.down then stepDown()drawAll()
elseif k==rb.drop then hardDrop()stepDown()drawAll()
elseif k==rb.rotR then rotCW()drawAll()
elseif k==rb.rotL then rotCCW()drawAll()
elseif k==rb.rot180 then rot180()drawAll()
elseif k==rb.hold then holdSwap()drawAll()
elseif k==rb.pause then paused=not paused;if mctl then mctl("pause",paused)end
elseif k==rb.exit then running=false end
elseif e[1]=="term_resize"then W,H=sz()B={window.create(P,1,1,W,H,false),window.create(P,1,1,W,H,false)};bi=1;rdr(B[1])drawAll()
end;musicTick()end
musicStop()return sc,lvl,ln end
local function inputLabel(x,y,s)mv(x,y)tx.setTextColor(colors.white)tx.setBackgroundColor(colors.black)pr(s)end
local function keyName(k)for n,v in pairs(keys)do if v==k then return n end end;return tostring(k)end
local function settingsUI(st)local sel=1;local it={"Music Vol","Start Level","Name","Left","Right","Down","Drop","Rot CW","Rot CCW","Rot 180","Hold","Pause","Exit","Back"}local map={"musicVol","startLvl","name","left","right","down","drop","rotR","rotL","rot180","hold","pause","exit"}
while true do clr(nil,colors.black)cen(3,"Tessera Settings")for i=1,#it do local y=5+i;local s=it[i]local v=""if i==1 then v=st.musicVol.."%"elseif i==2 then v=st.startLvl elseif i==3 then v=st.name else if i<=13 and i>=4 then v=keyName(st.rebind[map[i]])end end;mv(5,y)tx.setTextColor(i==sel and colors.yellow or colors.white)pr(s..": "..tostring(v))end;mv(5,5+#it+2)tx.setTextColor(colors.gray)pr("Arrows/Enter, ESC to back")sw()
local e={ev()}if e[1]=="key"then local k=e[2]if k==keys.up then sel=(sel-2)%#it+1 elseif k==keys.down then sel=sel%#it+1 elseif k==keys.left then if sel==1 then st.musicVol=math.max(0,st.musicVol-5)elseif sel==2 then st.startLvl=math.max(1,st.startLvl-1)end elseif k==keys.right then if sel==1 then st.musicVol=math.min(100,st.musicVol+5)elseif sel==2 then st.startLvl=math.min(20,st.startLvl+1)end elseif k==keys.enter then if sel==3 then clr(nil,colors.black)cen(8,"Enter name:")mv(5,10)tx.setTextColor(colors.white)tx.setBackgroundColor(colors.black)local s=""while true do sw()local evn={ev()}if evn[1]=="char"then s=s..evn[2]mv(5,10)pr(string.rep(" ",W-10))mv(5,10)pr(s)elseif evn[1]=="key"and evn[2]==keys.backspace then s=s:sub(1,#s-1)mv(5,10)pr(string.rep(" ",W-10))mv(5,10)pr(s)elseif evn[1]=="key"and (evn[2]==keys.enter or evn[2]==keys.numPadEnter)then break end end;if #s>0 then st.name=s end
elseif sel>=4 and sel<=13 then cen(8,"Press new key...")sw()local ke={ev()}while ke[1]~="key"do ke={ev()}end;st.rebind[map[sel]]=ke[2]end elseif sel==14 then saveSet(st)break end
elseif e[1]=="key"and e[2]==keys.escape then saveSet(st)break end end end
local function leaderboardUI()local t=loadLB()local off=0 while true do clr(nil,colors.black)cen(3,"Leaderboard (Top 100)")for i=1,math.min(15,#t-off)do local r=t[i+off]mv(3,4+i)tx.setTextColor(colors.white)pr(string.format("%2d. %-10s %7d  L%02d  %3d  %s",i+off,r.n:sub(1,10),r.s,r.l,r.ln,r.d or ""))end;mv(3,22)tx.setTextColor(colors.gray)pr("Up/Down scroll, ESC to back")sw()local e={ev()}if e[1]=="key"then if e[2]==keys.up then off=math.max(0,off-1)elseif e[2]==keys.down then off=math.min(math.max(0,#t-15),off+1)elseif e[2]==keys.escape or e[2]==keys.enter then break end elseif e[1]=="term_resize"then W,H=sz()B={window.create(P,1,1,W,H,false),window.create(P,1,1,W,H,false)};bi=1;rdr(B[1])end end end
local function mainMenu(st)
musicMenu(st.musicVol)
local sel=1;local it={"PLAY","SETTINGS","LEADERBOARD","EXIT"}
while true do clr(nil,colors.black)cen(5,"TESSERA")for i=1,#it do mv(math.floor(W/2-6),7+i)tx.setTextColor(i==sel and colors.yellow or colors.white)tx.setBackgroundColor(colors.black)pr(it[i])end;mv(2,H)tx.setTextColor(colors.gray)pr("v".._HOST.."  VOL "..st.musicVol.."%  User "..(st.name or "YOU"))sw()local e={ev()}if e[1]=="key"then local k=e[2]if k==keys.up then sel=(sel-2)%#it+1 elseif k==keys.down then sel=sel%#it+1 elseif k==keys.enter then if sel==1 then return "play"elseif sel==2 then settingsUI(st)musicMenu(st.musicVol)elseif sel==3 then leaderboardUI()musicMenu(st.musicVol)elseif sel==4 then return "exit"end elseif k==keys.q then return "exit"end elseif e[1]=="term_resize"then W,H=sz()B={window.create(P,1,1,W,H,false),window.create(P,1,1,W,H,false)};bi=1;rdr(B[1])end;musicTick()end end
local st=loadSet()
while true do local act=mainMenu(st)if act=="play"then local sc,l,ln=gameLoop(st)pushLB(st.name or "YOU",sc,l,ln)
local k=nil;while k~=keys.enter and k~=keys.escape do clr(nil,colors.black)cen(8,"GAME OVER")cen(10,"Score: "..sc.."  Level: "..l.."  Lines: "..ln)cen(12,"Enter=Menu  Esc=Exit")sw()local e={ev()}if e[1]=="key"then k=e[2]end end;if k==keys.escape then break end
else break end end
musicStop()tx.setCursorBlink(true)
