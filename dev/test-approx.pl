use String::Approx 'amatch';


@inputs = qw/ test1 t2st2 trdas test3 testing hallo/;
@matches = amatch('test2',@inputs);
print '';
