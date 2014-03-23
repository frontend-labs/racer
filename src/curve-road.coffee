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
            maxy = height

            ctx.clearRect 0, 0, width, height
            
            #render only background
            Render.background ctx, background, width, height, BACKGROUND.SKY, skyOffset
            Render.background ctx, background, width, height, BACKGROUND.HILLS, hillOffset
            Render.background ctx, background, width, height, BACKGROUND.TREES, treeOffset

            x = 0
            n = 0
            segment = null
            dx = -(baseSegment.curve * basePercent)

            while n < drawDistance
                #get a segment of the segment collection
                segment = segments[(baseSegment.index + n) % segments.length]

                segment.looped = segment.index < baseSegment.index
                segment.fog = Util.exponentialFog(n/drawDistance, fogDensity)

                Util.project segment.p1, 
                             ( playerX * roadWidth ) - x, 
                             camHeight, 
                             position - (if segment.looped then trackLength else 0),
                             camDepth, 
                             width, 
                             height, 
                             roadWidth

                Util.project segment.p2, 
                             ( playerX * roadWidth ) - x - dx, 
                             camHeight, 
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
                if (segment.p1.camera.z <= camDepth) or ( segment.p2.screen.y >= maxy )
                    n++
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

            Render.player ctx, width, height, resolution, roadWidth, sprites, speed/maxSpeed,
                            camDepth/playerZ,
                            width/2,
                            height,
                            speed * (if keyLeft then -1 else if keyRight then  1 else 0),
                            0
            return

        ###################################################
        #Build Road Geometry
        ###################################################
        addSegment = (curve)->
            n = segments.length
            segments.push
                index: n
                p1: 
                    world:
                        z: n * segmentLength
                    camera:{}
                    screen:{}
                p2:
                    world:
                        z: (n+1) * segmentLength
                    camera:{}
                    screen:{}
                curve: curve
                color: if Math.floor(n/rumbleLength) % 2 then COLORS.DARK else COLORS.LIGHT
            return

        addRoad = (enter, hold, leave, curve)->
            n = 0
            while n < enter
                addSegment Util.easeIn(0, curve, n/enter)
                n++
            while n < hold
                addSegment curve
                n++
            while n < leave
                addSegment Util.easeInOut(curve, 0, n/leave)
                n++
            return

        addStraight = (num = ROAD.LENGTH.MEDIUM)->
            addRoad(num, num, num, 0)
            return

        addCurve = (num = ROAD.LENGTH.MEDIUM, curve = ROAD.CURVE.MEDIUM) ->
            addRoad(num, num, num, curve)
            return
            
        addSCurves = () ->
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.EASY
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.MEDIUM
            return

        resetRoad = ()->
            segments = []
            n = 0

            addStraight ROAD.LENGTH.SHORT/4
            addSCurves()
            addStraight ROAD.LENGTH.LONG
            addCurve ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM
            addCurve ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM
            addStraight()
            addSCurves()
            addCurve(ROAD.LENGTH.LONG, -ROAD.CURVE.MEDIUM)
            addCurve(ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM)
            addStraight()
            addSCurves()
            addCurve(ROAD.LENGTH.LONG, -ROAD.CURVE.EASY)


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
