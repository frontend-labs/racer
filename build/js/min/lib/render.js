/*! racer 16/03/2014 */
define(["../lib/utils","../lib/debugger","../settings/colors","../settings/sprites"],function(Utils,Debugger,COLORS,SPRITES){var Render;return Render={polygon:function(ctx,x1,y1,x2,y2,x3,y3,x4,y4,color){Debugger.element("polygon","polygon: x1:"+x1+",y1:"+y1+",x2:"+x2+",y2:"+y2+",x3:"+x3+",y3:"+y3+",x4:"+x4+",y4:"+y4+",color:"+color),ctx.fillStyle=color,ctx.beginPath(),ctx.moveTo(x1,y1),ctx.lineTo(x2,y2),ctx.lineTo(x3,y3),ctx.lineTo(x4,y4),ctx.closePath(),ctx.fill()},segment:function(ctx,width,lanes,x1,y1,w1,x2,y2,w2,fog,color){var l1,l2,lane,lanew1,lanew2,lanex1,lanex2,r1,r2;if(Debugger.element("Render-segment","Render Segment: x1: "+x1+",y1: "+y1+" ,x2: "+x2+" ,y2: "+y2+" ,w2: "+w2+" ,fog: "+fog+" ,color: "+color),r1=Render.rumbleWidth(w1,lanes),r2=Render.rumbleWidth(w2,lanes),l1=Render.laneMarkerWidth(w1,lanes),l2=Render.laneMarkerWidth(w2,lanes),ctx.fillStyle=color.grass,ctx.fillRect(0,y2,width,y1-y2),Render.polygon(ctx,x1-w1-r1,y1,x1-w1,y1,x2-w2,y2,x2-w2-r2,y2,color.rumble),Render.polygon(ctx,x1+w1+r1,y1,x1+w1,y1,x2+w2,y2,x2+w2+r2,y2,color.rumble),Render.polygon(ctx,x1-w1,y1,x1+w1,y1,x2+w2,y2,x2-w2,y2,color.road),color.lane)for(lanew1=2*w1/lanes,lanew2=2*w2/lanes,lanex1=x1-w1+lanew1,lanex2=x2-w2+lanew2,lane=1;lanes>lane;)Render.polygon(ctx,lanex1-l1/2,y1,lanex1+l1/2,y1,lanex2+l2/2,y2,lanex2-l2/2,y2,color.lane),lanex1+=lanew1,lanex2+=lanew2,lane++;Render.fog(ctx,0,y1,width,y2-y1,fog)},background:function(ctx,background,width,height,layer,rotation,offset){var destH,destW,destX,destY,imageH,imageW,sourceH,sourceW,sourceX,sourceY;rotation=rotation||0,offset=offset||0,imageW=layer.w/2,imageH=layer.h,sourceX=layer.x+Math.floor(layer.w*rotation),sourceY=layer.y,sourceW=Math.min(imageW,layer.x+layer.w-sourceX),sourceH=imageH,destX=0,destY=offset,destW=Math.floor(width*(sourceW/imageW)),destH=height,ctx.drawImage(background,sourceX,sourceY,sourceW,sourceH,destX,destY,destW,destH),imageW>sourceW&&ctx.drawImage(background,layer.x,sourceY,imageW-sourceW,sourceH,destW-1,destY,width-destW,destH)},sprite:function(ctx,width,height,resolution,roadWidth,sprites,sprite,scale,destX,destY,offsetX,offsetY,clipY){var clipH,destH,destW;return destW=sprite.w*scale*width/2*SPRITES.SCALE*roadWidth,destH=sprite.h*scale*width/2*SPRITES.SCALE*roadWidth,destX+=destW*(offsetX||0),destY+=destH*(offsetY||0),clipH=clipY?Math.max(0,destY+destH+clipY):0,destH>clipH?ctx.drawImage(sprites,sprite.x,sprite.y,sprite.w,sprite.h-sprite.h*clipH/destH,destX,destY,destW,destH-clipH):void 0},player:function(ctx,width,height,resolution,roadWidth,sprites,speedPercent,scale,destX,destY,steer,updown){var bounce,sprite;return bounce=1.5*Math.random()*speedPercent*resolution*Utils.randomChoice([-1,1]),sprite=steer>0?updown>0?SPRITES.PLAYER_UPHILL_LEFT:SPRITES.PLAYER_LEFT:steer>0?updown>0?SPRITES.PLAYER_UPHILL_RIGHT:SPRITES.PLAYER_RIGHT:updown>0?SPRITES.PLAYER_UPHILL_STRAIGHT:SPRITES.PLAYER_STRAIGHT,Render.sprite(ctx,width,height,resolution,roadWidth,sprites,sprite,scale,destX,destY+bounce,-.5,-1)},fog:function(ctx,x,y,width,height,fog){1>fog&&(ctx.globalAlpha=1-fog,ctx.fillStyle=COLORS.FOG,ctx.fillRect(x,y,width,height),ctx.globalAlpha=1)},rumbleWidth:function(projectedRoadWidth,lanes){return projectedRoadWidth/Math.max(6,2*lanes)},laneMarkerWidth:function(projectedRoadWidth,lanes){return projectedRoadWidth/Math.max(32,8*lanes)}}});