define([
        'lib/dom'
        'lib/utils'
        'lib/render'
        'lib/game'
        'lib/stats'
        'settings/key'
        'settings/background'
        'settings/colors'],
    (DOM, Util, Render, Game, Stats, KEY, BACKGROUND, COLORS)->

        fps = 60
        step = 1/fps
        width = 1024
        height = 768
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
        accel = maxSpeed / 5
        breaking = -maxSpeed
        decel = -maxSpeed/5
        offRoadDecel = -maxSpeed/2
        offRoadLimit = maxSpeed/4

        keyLeft = false
        keyRight = false
        keyFaster = false
        keySlower = false


        console.log('canvas', canvas)
        ###################################################
        #Update the game world
        ###################################################
        update = (dt)->
            console.log('update!')
            pos = Util.increase(position, dt * speed, trackLength)
            dx = dt * 2 * (speed/maxSpeed)

            if keyLeft
                playerX = playerX - dx
            else if keyRight
                playerX = playerX + dx

            if keyFaster
                speed = Util.accelerate speed, accel, dt
            else if keySlower
                speed = Util.accelerate speed, breaking, dt
            else
                speed = Util.accelerate speed, decel, dt

            if (playerX < -1) or (playerX > 1) and (speed > offRoadLimit)
                speed = Util.accelerate speed, offRoadDecel, dt

            playerX = Util.limit playerX, -2, 2
            speed = Util.limit speed, 0, maxSpeed
            return


        ###################################################
        #Render the game world
        ###################################################
        render = ()->
            console.log('render')
            baseSegment = findSegment position
            maxy = height

            ctx.clearRect 0, 0, width, height

            Render.background ctx, background, width, height, BACKGROUND.SKY
            Render.background ctx, background, width, height, BACKGROUND.HILLS
            Render.background ctx, background, width, height, BACKGROUND.TREES

            indexDrawDistance = 0
            segment = null
            while indexDrawDistance < drawDistance
                segment = segments[(baseSegment.index + indexDrawDistance) % segments.length]
                segment.looped = segments.index < baseSegment.index
                segment.fog = Util.exponentialFog(indexDrawDistance/drawDistance, fogDensity)

                projectPrms =
                    camX: playerX * roadWidth
                    camY: camHeight
                    camZ: position - (if segment.looped then trackLength else 0)
                    camDepth: camDepth 
                    width: width
                    height: height
                    roadWidth: roadWidth

                Util.project segment.p1, 
                             projectPrms.camX, 
                             projectPrms.camY, 
                             projectPrms.camZ,
                             projectPrms.camDepth, 
                             projectPrms.width, 
                             projectPrms.height, 
                             projectPrms.roadWidth

                Util.project segment.p2, 
                             projectPrms.camX, 
                             projectPrms.camY, 
                             projectPrms.camZ,
                             projectPrms.camDepth, 
                             projectPrms.width, 
                             projectPrms.height, 
                             projectPrms.roadWidth

                #if segment.p1.camera.z <= camDepth or segment.p2.screen.y >= maxy
                    #continue
                
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
                indexDrawDistance++

            Render.player ctx, width, height, resolution, roadWidth, sprites, speed/maxSpeed,
                            camDepth/playerZ,
                            width/2,
                            height,
                            speed * (if keyLeft? then -1 else if keyRight? then  1 else 0),
                            0
            return

        ###################################################
        #Build Road Geometry
        ###################################################
        resetRoad = ()->
            console.log 'resetRoad'
            segments = []
            indexSegments = 0
            indexRumble = 0

            while indexSegments < 500
                segments.push
                    index: indexSegments
                    p1: 
                        world:
                            z: indexSegments * segmentLength
                        camera: {}
                        screen: {}
                    p2: 
                        world:
                            z: ( indexSegments + 1 ) * segmentLength
                        camera: {}
                        screen: {}
                    color: if ( Math.floor( indexSegments / rumbleLength) % 2 )?  then COLORS.DARK else COLORS.LIGHT
                indexSegments++

            segments[findSegment(playerZ).index + 2].color = COLORS.START
            segments[findSegment(playerZ).index + 3].color = COLORS.START

            while indexRumble < rumbleLength
                segments[segments.length - 1 - indexRumble].color = COLORS.FINISH
                indexRumble++

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
                { keys: [KEY.LEFT,  KEY.A], mode: 'down', action: ()-> keyLeft   = true; },
                { keys: [KEY.RIGHT, KEY.D], mode: 'down', action: ()-> keyRight  = true; },
                { keys: [KEY.UP,    KEY.W], mode: 'down', action: ()-> keyFaster = true; },
                { keys: [KEY.DOWN,  KEY.S], mode: 'down', action: ()-> keySlower = true; },
                { keys: [KEY.LEFT,  KEY.A], mode: 'up',   action: ()-> keyLeft   = false; },
                { keys: [KEY.RIGHT, KEY.D], mode: 'up',   action: ()-> keyRight  = false; },
                { keys: [KEY.UP,    KEY.W], mode: 'up',   action: ()-> keyFaster = false; },
                { keys: [KEY.DOWN,  KEY.S], mode: 'up',   action: ()-> keySlower = false; }
            ]
            ready:(images)->
                background = images[0]
                sprites = images[1]
                reset()
                return
        })

        reset = (opts)->
            console.log('reset!')
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

            if( segments.length is 0 or options.segmentLength or options.rumbleLength)
                resetRoad()
        return
)
