define(->
    Debugger =
        storageElements: []
        createSector:(sector)->
            body = document.getElementsByTagName('body')[0]
            body.appendChild(sector)
            return

        updateSector:(id, value)->
            sector = document.getElementById( id )
            sector.innerHTML = value
            return
        isLiteralObject: (element)->
            _test = element
            if typeof element isnt 'object' or element is null
                false
            else
                (->
                    while(!false)
                        if(Object.getPrototypeOf(_test = Object.getPrototypeOf(_test))) is null
                            break
                    return Object.getPrototypeOf(element) is _test
                )()

        element:(label, value)->
            #isliteralobject?
            if @isLiteralObject(value)
                value = JSON.stringify(value)

            if @storageElements.indexOf(label) is -1
               @storageElements.push(label)
               sector = document.createElement('div')
               sector.id = label
               @createSector(sector)
            else
               @updateSector(label, value)

    return Debugger
)
