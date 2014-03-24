define([
        'lib/dom'
        'lib/utils'
        'lib/debugger'
        'lib/render'
        'lib/game'
        'lib/stats'
        'settings/key'
        'settings/background'
        'settings/colors'],
    (DOM, Util, Debugger, Render, Game, Stats, KEY, BACKGROUND, COLORS)->

        fps = 60
        step = 1/fps
        width = 1024
        height = 768

        #init vars enterily of render in curves
        centrifugal = 0.3           #centrifugal force multiplier when going around curves
        offRoadDecel = 0.99         #speed multiplier when off road (e.g you lose 2% speed each update frame)
        skySpeed = 0.001            #background sky layer scroll speed when going around curve (or up hill)
        hillSpeed = 0.002           #background hill layer scroll speed when going around curve (or up hill)
        treeSpeed = 0.003           #background tree layer scroll speed when going around curve (or up hill)
        skyOffset = 0               #current sky scroll offset
        hillOffset = 0              #current hill scroll offset
        treeOffset = 0              #current tree scroll offset
        #end vars of render curves

        segments = []
        stats = Game.stats('fps')
        canvas = DOM.get('canvas')
        ctx = canvas.getContext('2d')
        background = null
        sprites = null
        resolution = null
        roadWidth = 2000
        segmentLength = 200
        rumbleLength = 3
        trackLength = null
        lanes = 3
        fieldOfView = 100
        camHeight = 1000
        camDepth = null
        drawDistance = 300
        playerX = 0
        playerZ = null
        fogDensity = 5
        position = 0
        speed = 0
        maxSpeed = segmentLength/step
        accel = maxSpeed/5
        breaking = -maxSpeed
        decel = -maxSpeed/5
        offRoadDecel = -maxSpeed/2
        offRoadLimit = maxSpeed/4

        keyLeft = false
        keyRight = false
        keyFaster = false
        keySlower = false

        #GLOBAL SETTING FOR THIS ESPECIAL ROAD
        ROAD =
            LENGTH:
                NONE: 0
                SHORT: 25
                MEDIUM: 50
                LONG: 100
            HILL:
                NONE: 0
                LOW: 20
                MEDIUM: 40
                HIGH: 60
            CURVE:
                NONE: 0
                EASY: 2
                MEDIUM: 4
                HARD: 6
        ###################################################
        #Update the game world
        ###################################################
        update = (dt)->

            playerSegment = findSegment(position + playerZ)
            speedPercent = speed/maxSpeed
            dx = dt * 2 * speedPercent

            position = Util.increase(position, dt * speed, trackLength)

            #Increase the offsets of the sky, hill and tree
            skyOffset = Util.increase(skyOffset, skySpeed * playerSegment.curve * speedPercent, 1)
            hillOffset = Util.increase(hillOffset, hillSpeed * playerSegment.curve * speedPercent, 1)
            treeOffset = Util.increase(treeOffset, treeSpeed * playerSegment.curve * speedPercent, 1)

            if keyLeft
                playerX = playerX - dx
            else if keyRight
                playerX = playerX + dx

            #update the player coordinate's of axis X
            playerX = playerX - (dx * speedPercent * playerSegment.curve * centrifugal)

            if keyFaster
                speed = Util.accelerate speed, accel, dt
            else if keySlower
                speed = Util.accelerate speed, breaking, dt
            else
                speed = Util.accelerate speed, decel, dt

            if ( (playerX < -1) or (playerX > 1) ) and (speed > offRoadLimit)
                speed = Util.accelerate speed, offRoadDecel, dt

            playerX = Util.limit playerX, -2, 2 #dont ever let player go too far out the bounds
            speed = Util.limit speed, 0, maxSpeed
            return

        ###################################################
        #Render the game world
        ###################################################
        render = ()->

            baseSegment = findSegment position
            basePercent = Util.percentRemaining position, segmentLength
            playerSegment = findSegment position+playerZ
            playerPercent = Util.percentRemaining position+playerZ, segmentLength
            playerY = Util.interpolate playerSegment.p1.world.y, playerSegment.p2.world.y, playerPercent
            maxy = height

            x = 0
            dx = -(baseSegment.curve * basePercent)

            ctx.clearRect 0, 0, width, height
            
            #render only background
            Render.background ctx, background, width, height, BACKGROUND.SKY, skyOffset, resolution * skySpeed * playerY
            Render.background ctx, background, width, height, BACKGROUND.HILLS, hillOffset, resolution * hillSpeed * playerY
            Render.background ctx, background, width, height, BACKGROUND.TREES, treeOffset, resolution * treeSpeed * playerY

            n = 0
            while n < drawDistance
                #get a segment of the segment collection
                segment = segments[(baseSegment.index + n) % segments.length]
                segment.looped = segment.index < baseSegment.index
                segment.fog = Util.exponentialFog(n/drawDistance, fogDensity)

                Util.project segment.p1, 
                             ( playerX * roadWidth ) - x, 
                             playerY + camHeight, 
                             position - (if segment.looped then trackLength else 0),
                             camDepth, 
                             width, 
                             height, 
                             roadWidth

                Util.project segment.p2, 
                             ( playerX * roadWidth ) - x - dx, 
                             playerY + camHeight, 
                             position - (if segment.looped then trackLength else 0),
                             camDepth, 
                             width, 
                             height, 
                             roadWidth
                             
                x = x + dx
                dx = dx + segment.curve

                #WARNING
                #======
                #ever makes the next segment of road
                #this conditional ever return true for create more segments when looping
                n++
                if (segment.p1.camera.z <= camDepth) or 
                   (segment.p2.screen.y >= segment.p1.screen.y) or
                   (segment.p2.screen.y >= maxy)
                    continue

                Render.segment ctx, width, lanes,
                                segment.p1.screen.x,
                                segment.p1.screen.y,
                                segment.p1.screen.w,
                                segment.p2.screen.x,
                                segment.p2.screen.y,
                                segment.p2.screen.w,
                                segment.fog,
                                segment.color

                maxy = segment.p2.screen.y

            Render.player ctx, width, height,
                            resolution, 
                            roadWidth, 
                            sprites,
                            speed/maxSpeed,
                            camDepth/playerZ,
                            width/2,
                            ( height / 2 ) - (camDepth/playerZ * Util.interpolate(playerSegment.p1.camera.y, playerSegment.p2.camera.y, playerPercent) * height/2),
                            speed * (if keyLeft then -1 else if keyRight then  1 else 0),
                            playerSegment.p2.world.y - playerSegment.p1.world.y
            return

        ###################################################
        #Build Road Geometry
        ###################################################
        lastY = ()->
            if segments.length is 0 then 0 else segments[segments.length - 1].p2.world.y

        addSegment = (curve, y)->
            n = segments.length
            segments.push
                index: n
                p1: 
                    world:
                        y: lastY()
                        z: n * segmentLength
                    camera:{}
                    screen:{}
                p2:
                    world:
                        y: y
                        z: (n+1) * segmentLength
                    camera:{}
                    screen:{}
                curve: curve
                color: if Math.floor(n/rumbleLength)%2 then COLORS.DARK else COLORS.LIGHT
            return

        addRoad = (enter, hold, leave, curve, y)->
            startY = lastY()
            endY = startY + ( Util.toInt(y, 0) * segmentLength )
            total = enter + hold + leave
            nEnter = 0
            nHold = 0
            nLeave = 0
            while nEnter < enter
                addSegment Util.easeIn(0, curve, nEnter/enter), Util.easeInOut(startY, endY, nEnter/total)
                nEnter++
            while nHold < hold
                addSegment curve, Util.easeInOut(startY, endY, (enter+nHold)/total)
                nHold++
            while nLeave < leave
                addSegment Util.easeInOut(curve, 0, nLeave/leave), Util.easeInOut(startY, endY, (enter+hold+nLeave)/total)
                nLeave++
            return

        addStraight = (n)->
            num = n or ROAD.LENGTH.MEDIUM
            addRoad(num, num, num, 0, 0)
            return

        addHill = (n, h) ->
            num = n or ROAD.LENGTH.MEDIUM
            _height = h or ROAD.HILL.MEDIUM
            addRoad(num, num, num, 0, _height)
            return

        addCurve = (n, c, h) ->
            num = n or ROAD.LENGTH.MEDIUM
            curve = c or ROAD.CURVE.MEDIUM
            _height = h or ROAD.HILL.NONE
            addRoad(num, num, num, curve, _height)
            return
            
        addLowRollingHills = (n, h)->
            num = n or ROAD.LENGTH.SHORT
            _height = h or ROAD.HILL.LOW
            addRoad num, num, num, 0, _height/2
            addRoad num, num, num, 0, -_height
            addRoad num, num, num, 0, _height
            addRoad num, num, num, 0, 0
            addRoad num, num, num, 0, _height/2
            addRoad num, num, num, 0, 0
            return

        addSCurves = () ->
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY, ROAD.HILL.NONE
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.EASY, -ROAD.HILL.LOW
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY, ROAD.HILL.MEDIUM
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.MEDIUM, -ROAD.HILL.MEDIUM
            return

        addDownhillToEnd = (n)->
            num = n or 200
            addRoad num, num, num, -ROAD.CURVE.EASY, -lastY()/segmentLength
            return

        resetRoad = ()->
            segments = []

            addStraight ROAD.LENGTH.SHORT/2
            addHill ROAD.LENGTH.SHORT, ROAD.HILL.LOW
            addLowRollingHills()
            addCurve ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.LOW
            addLowRollingHills()
            addCurve ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM
            addStraight()
            addCurve ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, -ROAD.HILL.LOW
            addHill ROAD.LENGTH.LONG, -ROAD.HILL.MEDIUM
            addStraight()
            addDownhillToEnd()

            segments[findSegment(playerZ).index + 2].color = COLORS.START
            segments[findSegment(playerZ).index + 3].color = COLORS.START

            nRumble = 0
            while nRumble < rumbleLength
                segments[ segments.length - 1 - nRumble ].color = COLORS.FINISH
                nRumble++

            trackLength = segments.length * segmentLength
            return

        findSegment = (z)->
            segments[Math.floor(z/segmentLength) % segments.length]

        ###################################################
        #THE GAME LOOP
        ###################################################
        Game.run({
            canvas: canvas
            render: render
            update: update
            stats: stats
            step: step
            imgs: ["background", "sprites"]
            keys: [
                { keys: [KEY.LEFT,  KEY.A], mode: 'down', action: ()-> keyLeft   = true;return},
                { keys: [KEY.RIGHT, KEY.D], mode: 'down', action: ()-> keyRight  = true;return},
                { keys: [KEY.UP,    KEY.W], mode: 'down', action: ()-> keyFaster = true;return},
                { keys: [KEY.DOWN,  KEY.S], mode: 'down', action: ()-> keySlower = true;return},
                { keys: [KEY.LEFT,  KEY.A], mode: 'up',   action: ()-> keyLeft   = false;return},
                { keys: [KEY.RIGHT, KEY.D], mode: 'up',   action: ()-> keyRight  = false;return},
                { keys: [KEY.UP,    KEY.W], mode: 'up',   action: ()-> keyFaster = false;return},
                { keys: [KEY.DOWN,  KEY.S], mode: 'up',   action: ()-> keySlower = false;return}
            ]
            ready:(images)->
                background = images[0]
                sprites = images[1]
                reset()
                return
        })

        reset = (opts)->
            options = opts or {}
            canvas.width = width = Util.toInt(options.width, width)
            canvas.height = height = Util.toInt(options.height, height)
            lanes = Util.toInt(options.lanes, lanes)
            roadWidth = Util.toInt(options.roadWidth, roadWidth)
            camHeight = Util.toInt(options.camHeight, camHeight)
            drawDistance = Util.toInt(options.drawDistance, drawDistance)
            fogDensity = Util.toInt(options.fogDensity, fogDensity)
            fieldOfView = Util.toInt(options.fieldOfView, fieldOfView)
            segmentLength = Util.toInt(options.segmentLength, segmentLength)
            rumbleLength = Util.toInt(options.rumbleLength, rumbleLength)
            camDepth = 1 / Math.tan( (fieldOfView/ 2) * Math.PI / 180)
            playerZ = camHeight * camDepth
            resolution = height / 480

            if( ( segments.length is 0 ) or ( options.segmentLength ) or ( options.rumbleLength ))
                resetRoad()
            return
        return
)
