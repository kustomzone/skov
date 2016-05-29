! Copyright (C) 2015-2016 Nicolas Pénet.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays combinators combinators.smart
compiler.units effects fry hashtables.private kernel listener
locals math.parser namespaces sequences splitting ui.gadgets
vectors vocabs.parser ;
QUALIFIED: vocabs
QUALIFIED: definitions
IN: skov.code

TUPLE: element < identity-tuple  name parent contents ;

TUPLE: vocab < element ;

TUPLE: definition < element  defined? alt ;
TUPLE: word-definition < definition  result ;
TUPLE: tuple-definition < definition ;

TUPLE: node < element ;
TUPLE: introduce < node ;
TUPLE: return < node ;
TUPLE: word < node  path ;
TUPLE: text < node ;
TUPLE: slot < node  initial-value ;
TUPLE: constructor < word ;
TUPLE: destructor < word ;
TUPLE: accessor < word ;
TUPLE: mutator < word ;

TUPLE: connector < element ;
TUPLE: input < connector  link ;
TUPLE: output < connector  id ;

TUPLE: special-input < input ;
TUPLE: special-output < output ;

UNION: special-connector  special-input special-output ;
UNION: definition-connector  introduce return ;

TUPLE: result < element ;

GENERIC: outputs>> ( obj -- seq )
GENERIC: tuples>> ( obj -- seq )
GENERIC: slots>> ( obj -- seq )
GENERIC: connectors>> ( obj -- seq )
GENERIC: introduces>> ( obj -- seq )
GENERIC: returns>> ( obj -- seq )
M: vocab vocabs>> ( elt -- seq ) contents>> [ vocab? ] filter ;
M: vocab definitions>> ( elt -- seq ) contents>> [ definition? ] filter ;
M: vocab words>> ( elt -- seq ) contents>> [ word-definition? ] filter ;
M: vocab tuples>> ( elt -- seq ) contents>> [ tuple-definition? ] filter ;
M: word-definition words>> ( elt -- seq ) contents>> [ word? ] filter ;
M: element connectors>> ( elt -- seq ) contents>> [ definition-connector? ] filter ;
M: node connectors>> ( elt -- seq ) contents>> [ connector? ] filter ;
M: element inputs>> ( elt -- seq ) contents>> [ input? ] filter ;
M: element outputs>> ( elt -- seq ) contents>> [ output? ] filter ;
M: word-definition inputs>> ( elt -- seq ) contents>> [ introduce? ] filter ;
M: word-definition outputs>> ( elt -- seq ) contents>> [ return? ] filter ;
M: word-definition introduces>> ( elt -- seq ) contents>> [ introduce? ] filter ;
M: word-definition returns>> ( elt -- seq ) contents>> [ return? ] filter ;
M: node slots>> ( elt -- seq ) contents>> [ slot? ] filter ;

:: add-element ( parent child -- parent )
     child parent >>parent parent [ ?push ] change-contents ;

: add-from-class ( parent child-class -- parent )
     new add-element ;

: add-with-name ( parent child-name child-class -- parent )
     new swap >>name add-element ;

: remove-from-parent ( child -- )
     dup parent>> contents>> remove-eq! drop ;

:: change-name ( str pair -- str )
    str pair first = [ pair second ] [ str ] if ;

: spaces>dashes ( str -- str )  " " "-" replace ;
: dashes>spaces ( str -- str )  "-" " " replace ;

GENERIC: factor-name ( obj -- str )

M: element factor-name
    name>> spaces>dashes ;

M: word factor-name
    name>> { 
      { "lazy filter" "lfilter" }
      { "while" "special-while" }
      { "until" "special-until" }
      { "if" "special-if" }
    }
    [ change-name ] each
    dup [ CHAR: { swap member? not ] [ CHAR: " swap member? not ] bi and
    [ spaces>dashes ] when ;

M: constructor factor-name
    name>> spaces>dashes "<" ">" surround ;

M: destructor factor-name
    name>> spaces>dashes ">" "<" surround ;

M: accessor factor-name
    name>> spaces>dashes ">>" append ;

M: mutator factor-name
    name>> spaces>dashes ">>" swap append ;

M: text factor-name
    name>> ;

M: vocab path>>
    parents reverse rest [ factor-name ] map "." join [ "scratchpad" ] when-empty ;

M: definition path>>
    parents reverse rest but-last [ factor-name ] map "." join [ "scratchpad" ] when-empty ;

: replace-quot ( seq -- seq )
    [ array? ] [ first [ "quot" swap subseq? not ] [ " quot" append ] smart-when ] smart-when ;

: convert-stack-effect ( stack-effect -- seq seq )
    [ in>> ] [ out>> ] bi [ [ replace-quot dashes>spaces ] map ] bi@ ;

: same-name-as-parent? ( word -- ? )
    dup parent>> [ name>> ] bi@ = ;

: input-output-names ( word -- seq seq )
    [ inputs>> ] [ outputs>> ] bi [ [ name>> ] map ] bi@ ;

:: in-out ( word -- seq seq )
    word factor-name :> name
    [ { { [ word same-name-as-parent? ] [ word parent>> input-output-names ] }
        { [ name CHAR: { swap member? ] [ { } { "sequence" } ] }
        { [ name string>number ] [ { } { "number" } ] }
        { [ name search not ] [ { } { } ] }
        [ name search dup vocabulary>> word path<< stack-effect convert-stack-effect ]
      } cond ] with-interactive-vocabs ;

: add-special-connectors ( node -- node )
    [ inputs>> empty? ] [ "invisible connector" special-input add-with-name ] smart-when
    [ outputs>> empty? ] [ "invisible connector" special-output add-with-name ] smart-when ;

GENERIC: (add-connectors) ( node -- node )
M: element (add-connectors)  ;
M: introduce (add-connectors)  f >>contents dup name>> output add-with-name ;
M: return (add-connectors)  f >>contents dup name>> input add-with-name ;
M: text (add-connectors)  f >>contents dup name>> output add-with-name add-special-connectors ;

M: word (add-connectors)
    f >>contents dup in-out
    [ [ input add-with-name ] each ]
    [ [ output add-with-name ] each ] bi*
    add-special-connectors ;

GENERIC: connect ( output input -- )

:: links ( output -- seq )
    output parent>> parent>> contents>> [ inputs>> [ link>> output eq? ] filter ] map concat ;

:: add-connectors ( elt -- elt )
    elt name>> [
      elt node? [
        elt inputs>> [ link>> ] map 
        elt outputs>> [ links ] map
      ] [ f f ] if :> saved-output-links :> saved-input-links
      elt (add-connectors)
      saved-input-links elt inputs>> [ connect ] 2each
      elt outputs>> saved-output-links [ [ connect ] with each ] 2each
    ] [ elt ] if ;

: order-connectors ( connector connector -- connector connector )
    dup output? [ swap ] when ;

: output-and-input? ( connector connector -- ? )
    [ output? ] [ input? ] bi* and ;

: same-word? ( connector connector -- ? )
    [ parent>> ] bi@ eq? ;

GENERIC: connected? ( connector -- ? )

M: node connected?
    connectors>> [ connected? ] any? ;

M: input connected?
    link>> output? ;

M: output connected?
    dup parent>> parent>> contents>> [ inputs>> [ link>> ] map ] map concat [ eq? ] with any? ;

: connected-inputs>> ( elt -- seq )  inputs>> [ connected? ] filter ;
: connected-outputs>> ( elt -- seq )  outputs>> [ connected? ] filter ;
: connected-connectors>> ( elf -- seq )  connectors>> [ connected? ] filter ;
: connected-contents>> ( elf -- seq )  contents>> [ connected? ] filter ;
: unconnected-contents>> ( elf -- seq )  contents>> [ connected? ] reject ;

M: input connect
    link<< ;

GENERIC: disconnect ( connector -- )

M: input disconnect
    f >>link drop ;

M: output disconnect
    links [ disconnect ] each ;

: ?connect ( connector connector -- )
    order-connectors 
    [ [ output-and-input? ] [ nip connected? not ] [ same-word? not ] 2tri and and ]
    [ connect ] smart-when* ;

: complete-graph? ( word -- ? )
    unconnected-contents>> empty? ;

: any-empty-name? ( word -- ? )
    contents>> [ name>> empty? ] any? ;

: executable? ( word -- ? )
   { [ complete-graph? ]
     [ inputs>> empty? ]
     [ outputs>> empty? ]
     [ words>> empty? not ]
     [ defined?>> ]
     [ any-empty-name? not ]
   } cleave>array t [ and ] reduce ;

: error? ( word -- ? )
    { [ complete-graph? not ]
      [ defined?>> not ]
      [ any-empty-name? ] 
      [ contents>> empty? ]
    } cleave>array f [ or ] reduce ;

CONSTANT: variadic-words { "add" "mul" "and" "or" "min" "max" }

: variadic? ( word -- ? )
    name>> variadic-words member? ;

: save-result ( str word  -- )
    swap dupd result new swap >>contents swap >>parent >>result drop ;

SYMBOL: skov-root
vocab new "●" >>name skov-root set-global

: set-output-ids ( definition -- definition )
    dup contents>> [ inputs>> ] map concat [ link>> ] map sift dup length iota [ >>id drop ] 2each ;

: forget-alt ( vocab/def -- )
    { { [ dup vocab? ] [ path>> vocabs:forget-vocab ] }
      { [ dup definition? ] [ alt>> [ [ definitions:forget ] with-compilation-unit ] when* ] }
      [ drop ]
    } cond ;
