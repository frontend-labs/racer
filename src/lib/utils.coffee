define(->
    Util =
        timestamp:->
            new Date().getTime()

        toInt:(obj, def)->
            if obj? 
               x = parseInt(obj, 10)
               return x unless isNaN(x)
            Util.toInt(def, 0)

        toFloat: (obj, def)->
            if obj?
               x = parseFloat(obj)
               return x unless isNaN(x)
            Util.toFloat(def, 0.0)

        limit: (value, min, max)->
            Math.max(min, Math.min(value, max))

        randomInt: (min, max)->
            Math.round(Util.interpolate(min, max, Math.random()))

        randomChoice: (opts)->
            opts[Util.randomInt(0, opts.length  - 1)]

        percentRemaining: (n, total)->
            n % total / total

        accelerate:(v, accel, dt)->
            v + (accel * dt)
        
        interpolate:(a, b, percent)->
            a + (b - a) * percent

        easeIn:(a, b, percent)->
            a + (b - a) * Math.pow(percent, 2)

        easeOut:(a, b, percent)->
            a + (b - a) * ( 1 - Math.pow(1 - percent, 2))

        easeInOut:(a, b, percent)->
            a + (b-a)*((-Math.cos(percent*Math.PI)/2) + 0.5)

        exponentialFog:(distance, density)->
            1 / (Math.pow(Math.E, (distance * distance * density)))

        increase: (start, increment, max)->
            result = start + increment
            while result >= max
                result -= max
            while result < 0
                result += max
            result

        project: (p, camX, camY, camZ, camDepth, width, height, roadWidth)->
            p.camera.x = ( p.world.x or 0 ) - camX
            p.camera.y = ( p.world.y or 0 ) - camY
            p.camera.z = ( p.world.z or 0 ) - camZ
            p.screen.scale = camDepth/p.camera.z
            p.screen.x = Math.round((width/2) + (p.screen.scale * p.camera.x * width/2))
            p.screen.y = Math.round((height/2) - (p.screen.scale * p.camera.y * height/2))
            p.screen.w = Math.round(( p.screen.scale * roadWidth * width/2 ))
            return

        overlap:(x1, w1, x2, w2, percent)->
            half = ppercent or 1/2
            min1 = x1 - (w1 * half)
            max1 = x1 + (w1 * half)
            min2 = x2 - (w2 * half)
            max2 = x2 + (w2 * half)

            return !( (max1 < min2) or (min1 > max2))

    return Util
)
