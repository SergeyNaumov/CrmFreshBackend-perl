package CRM::Events;
# получаем события
sub process{
    my $s=shift;
    my $events=$s->{config}->{events};
    my $response={};
    if($events){

    }
    else{
        $response={success=>1, message=>'никакие события выводить не нужно'}
    }
    $s->print_json({
        $response
    })->end;

}
return 1;