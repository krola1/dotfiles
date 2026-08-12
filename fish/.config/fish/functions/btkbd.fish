# Kjør btkbd (BT-tastatur/mus-emulator) fra scripts/btkbd, uansett hvor
# terminalen står, siden den peker fast på $dotfiles_dir i stedet for $PWD.
function btkbd --description 'Kjør btkbd (Bluetooth-tastatur/mus-emulator)'
    sudo python3 $dotfiles_dir/scripts/btkbd/btkbd.py $argv
end
