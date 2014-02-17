/*! racer 17/02/2014 */
define(["lib/dom","lib/utils","lib/game","lib/stats","settings/key","settings/background"],function(DOM,Util,Game,Stats,KEY,BACKGROUND){var accel,background,breaking,camDepth,camHeight,canvas,ctx,decel,drawDistance,fieldOfView,findSegment,fogDensity,fps,height,keyFaster,keyLeft,keyRight,keySlower,lanes,maxSpeed,offRoadDecel,offRoadLimit,playerX,playerZ,position,render,resetRoad,resolution,roadWidth,rumbleLength,segmentLength,segments,speed,sprites,stats,step,trackLength,update,width;fps=60,step=1/fps,width=1024,height=768,segments=[],stats=Game.stats("fps"),canvas=DOM.get("canvas"),ctx=canvas.getContext("2d"),background=null,sprites=null,resolution=null,roadWidth=2e3,segmentLength=200,rumbleLength=3,trackLength=null,lanes=3,fieldOfView=100,camHeight=1e3,camDepth=null,drawDistance=300,playerX=0,playerZ=null,fogDensity=5,position=0,speed=0,maxSpeed=segmentLength/step,accel=maxSpeed/5,breaking=-maxSpeed,decel=-maxSpeed/5,offRoadDecel=-maxSpeed/2,offRoadLimit=maxSpeed/4,keyLeft=!1,keyRight=!1,keyFaster=!1,keySlower=!1,update=function(dt){var dx,pos;pos=Util.increase(position,dt*speed,trackLength),dx=2*dt*(speed/maxSpeed),keyLeft?playerX-=dx:keyRight&&(playerX+=dx),speed=keyFaster?Util.accelerate(speed,accel,dt):keySlower?Util.accelerate(speed,breaking,dt):Util.accelerate(speed,decel,dt),(-1>playerX||playerX>1&&speed>offRoadLimit)&&(speed=Util.accelerate(speed,offRoadDecel,dt)),playerX=Util.limit(playerX,-2,2),speed=UTil.limit(speed,0,maxSpeed)},render=function(){var baseSegment,indexDrawDistance,maxy,projectPrms,segment;for(baseSegment=findSegment(position),maxy=height,ctx.clearRect(0,0,width,height),Render.background(ctx,background,width,height,BACKGROUND.SKY),Render.background(ctx,background,width,height,BACKGROUND.HILLS),Render.background(ctx,background,width,height,BACKGROUND.TREES),indexDrawDistance=0;drawDistance>indexDrawDistance;)segment=segments[(baseSegment.index+indexDrawDistance)%segments.length],segment.looped=segments.index<baseSegment.index,segment.fog=Util.exponentialFog(indexDrawDistance/drawDistance,fogDensity),projectPrms={camX:playerX*roadWidth,camY:camHeight,camZ:position-(("function"==typeof segment.looped?segment.looped(trackLength):void 0)?void 0:0),camDepth:cameraDepth,width:width,height:height,roadWidth:roadWidth},Util.project(segment.p1,projectPrms.camX,projectPrms.camY,projectPrms.camZ,projectPrms.camDepth,projectPrms.width,projectPrms.height,projectPrms.roadWidth),Util.project(segment.p2,projectPrms.camX,projectPrms.camY,projectPrms.camZ,projectPrms.camDepth,projectPrms.width,projectPrms.height,projectPrms.roadWidth),segment.p1.camera.z<=cameraDepth||segment.p2.screen.y>=maxy||(Render.segment(ctx,width,lanes,segment.p1.screen.x,segment.p1.screen.y,segment.p1.screen.w,segment.p2.screen.x,segment.p2.screen.y,segment.p2.screen.w,segment.fog,segment.color),maxy=segment.p2.screen.y,indexDrawDistance++);Render.player(ctx,width,height,resolution,roadWidth,sprites,speed/maxSpeed,cameraDepth/playerZ,width/2,height,speed*(null!=keyLeft?-1:null!=keyRight?1:0),0)},resetRoad=function(){var indexRumble,indexSegments;for(segments=[],indexSegments=0,indexRumble=0;500>indexSegments;)segments.push({index:indexSegments,p1:{world:{z:n*segmentLength},camera:{},screen:{}},p2:{world:{z:(n+1)*segmentLength},camera:{},screen:{}},color:Math.floor(indexSegments/rumbleLength)%2!=null?COLORS.DARK:COLORS.LIGHT}),indexSegments++;for(segments[findSegment(playerZ).index+2].color=COLORS.START,segments[findSegment(playerZ).index+3].color=COLORS.START;rumbleLength>indexRumble;)segments[segments.length-1-indexRumble].color=COLORS.FINISH,indexRumble++;trackLength=segments.length*segmentLength},findSegment=function(z){return segments[Math.floor(z/segmentLength)%segments.length]},Game.run({canvas:canvas,render:render,update:update,stats:stats,step:step,imgs:["background","sprites"],keys:[{keys:[KEY.LEFT,KEY.A],mode:"down",action:function(){return keyLeft=!0}},{keys:[KEY.RIGHT,KEY.D],mode:"down",action:function(){return keyRight=!0}},{keys:[KEY.UP,KEY.W],mode:"down",action:function(){return keyFaster=!0}},{keys:[KEY.DOWN,KEY.S],mode:"down",action:function(){return keySlower=!0}},{keys:[KEY.LEFT,KEY.A],mode:"up",action:function(){return keyLeft=!1}},{keys:[KEY.RIGHT,KEY.D],mode:"up",action:function(){return keyRight=!1}},{keys:[KEY.UP,KEY.W],mode:"up",action:function(){return keyFaster=!1}},{keys:[KEY.DOWN,KEY.S],mode:"up",action:function(){return keySlower=!1}}]})});