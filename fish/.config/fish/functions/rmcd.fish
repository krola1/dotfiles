# NB: sletter hele nåværende mappe rekursivt uten bekreftelse - bruk med omhu.
function rmcd --description 'Slett nåværende mappe rekursivt og gå til foreldremappen'
    set current $PWD
    cd ..
    and rm -rf $current
end
