define([
        '../lib/utils',
        '../lib/debugger',
        '../settings/colors',
        '../settings/sprites'], 
    ( Utils, Debugger, COLORS, SPRITES)->

        Render =
            polygon:(ctx, x1, y1, x2, y2, x3, y3, x4, y4, color)->
                Debugger.element "polygon", "polygon: x1:" + x1 + ",y1:" + y1 + ",x2:" + x2 + ",y2:" + y2 + ",x3:" + x3 + ",y3:" + y3 + ",x4:" + x4 + ",y4:" + y4 + ",color:" + color
                ctx.fillStyle = color
                ctx.beginPath()
                ctx.moveTo x1, y1
                ctx.lineTo x2, y2
                ctx.lineTo x3, y3
                ctx.lineTo x4, y4
                ctx.closePath()
                ctx.fill()
                return

            segment:(ctx, width, lanes, x1, y1, w1, x2, y2, w2, fog, color)->
                Debugger.element('Render-segment', "Render Segment: x1: #{ x1 },y1: #{ y1 } ,x2: #{ x2 } ,y2: #{ y2 } ,w2: #{ w2} ,fog: #{ fog } ,color: #{ color }")
                r1 = Render.rumbleWidth w1, lanes
                r2 = Render.rumbleWidth w2, lanes
                l1 = Render.laneMarkerWidth w1, lanes
                l2 = Render.laneMarkerWidth w2, lanes

                ctx.fillStyle = color.grass
                ctx.fillRect(0, y2, width, y1 - y2)

                Render.polygon ctx, x1-w1-r1, y1, x1-w1, y1, x2-w2, y2, x2-w2-r2, y2, color.rumble
                Render.polygon ctx, x1+w1+r1, y1, x1+w1, y1, x2+w2, y2, x2+w2+r2, y2, color.rumble
                Render.polygon ctx, x1-w1,    y1, x1+w1, y1, x2+w2, y2, x2-w2,    y2, color.road

                if color.lane
                    lanew1 = w1 * 2 /lanes
                    lanew2 = w2 * 2 /lanes
                    lanex1 = x1 - w1 + lanew1
                    lanex2 = x2 - w2 + lanew2

                    lane = 1
                    while lane < lanes
                        Render.polygon ctx, lanex1 - l1/2, y1, lanex1 + l1/2, y1, lanex2 + l2/2, y2, lanex2 - l2/2, y2, color.lane
                        lanex1 += lanew1
                        lanex2 += lanew2
                        lane++

                Render.fog ctx, 0, y1, width, y2-y1, fog
                return

            background:(ctx, background, width, height, layer, rotation, offset)->
                rotation = rotation or 0
                offset = offset or 0

                imageW = layer.w / 2
                imageH = layer.h

                sourceX = layer.x + Math.floor ( layer.w * rotation )
                sourceY = layer.y
                sourceW = Math.min(imageW, ( layer.x + layer.w - sourceX ))
                sourceH = imageH

                destX = 0
                destY = offset
                destW = Math.floor ( width * (sourceW/imageW) )
                destH = height

                ctx.drawImage background, sourceX, sourceY, sourceW, sourceH, destX, destY, destW, destH
                if sourceW < imageW
                    ctx.drawImage background, layer.x, sourceY, imageW-sourceW, sourceH, destW-1, destY, width-destW, destH
                return

            sprite:(ctx, width, height, resolution, roadWidth, sprites, sprite, scale, destX, destY, offsetX, offsetY, clipY)->
                destW = (sprite.w * scale * width/2) * (SPRITES.SCALE * roadWidth)
                destH = (sprite.h * scale * width/2) * (SPRITES.SCALE * roadWidth)

                destX = destX + (destW * (offsetX or 0))
                destY = destY + (destH * (offsetY or 0))

                clipH = if clipY then Math.max(0, destY + destH + clipY) else 0

                if clipH < destH
                    ctx.drawImage sprites, sprite.x, sprite.y, sprite.w, sprite.h - (sprite.h * clipH/destH), destX, destY, destW, destH - clipH

            player:(ctx, width, height, resolution, roadWidth, sprites, speedPercent, scale, destX, destY, steer, updown)->
                bounce = (1.5 * Math.random() * speedPercent * resolution) * Utils.randomChoice([-1, 1])
                if(steer > 0)
                    sprite = if updown > 0 then SPRITES.PLAYER_UPHILL_LEFT else SPRITES.PLAYER_LEFT
                else if steer > 0
                    sprite = if updown > 0 then SPRITES.PLAYER_UPHILL_RIGHT else SPRITES.PLAYER_RIGHT
                else
                    sprite = if updown > 0 then SPRITES.PLAYER_UPHILL_STRAIGHT else SPRITES.PLAYER_STRAIGHT

                Render.sprite ctx, width, height, resolution, roadWidth, sprites, sprite, scale, destX, destY + bounce, -0.5, -1

            fog:(ctx, x, y, width, height, fog)->
                if fog < 1
                    ctx.globalAlpha = 1 - fog
                    ctx.fillStyle = COLORS.FOG
                    ctx.fillRect(x, y, width, height)
                    ctx.globalAlpha = 1
                return

            rumbleWidth:(projectedRoadWidth, lanes)->
                projectedRoadWidth/Math.max(6, 2 * lanes)

            laneMarkerWidth:(projectedRoadWidth, lanes)->
                projectedRoadWidth/Math.max(32, 8 * lanes)
                
        return Render
)
