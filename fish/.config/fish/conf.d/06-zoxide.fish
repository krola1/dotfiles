# ==============================================================================
# zoxide: smart "cd" som lærer hvilke mapper du besøker ofte.
# Må initialiseres før 10-aliases.fish tar i bruk `z`-funksjonen
# (selve funksjonen kalles først når brukeren skriver `cd`, så
# lasterekkefølgen mellom filene her har ikke noe å si i praksis,
# men vi holder den logisk før aliaset for lesbarhetens skyld).
# ==============================================================================

zoxide init fish | source
