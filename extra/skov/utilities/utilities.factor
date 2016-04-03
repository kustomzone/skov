! Copyright (C) 2015 Nicolas Pénet.
USING: arrays classes combinators.smart kernel locals math
math.order math.vectors prettyprint sequences ;
IN: skov.utilities

: v-sum ( seq -- n )
    { 0 0 } [ v+ ] reduce ;

:: next-nth ( seq elt n -- elt' )
    seq [ elt eq? ] find drop n +
    seq length 1 - min 0 max
    seq nth ;
