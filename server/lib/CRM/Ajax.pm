package CRM::Ajax;
use utf8;
use strict;
use Data::Dumper;

sub process{
    
    my %arg=@_;
    my $form=CRM::read_conf(%arg);
    my $s=$arg{'s'};
    my $R=$s->request_content(from_json=>1);
    #print Dumper({r=>$R});
    my $result;
    my $name=$arg{name};
    
    if(exists($form->{AJAX}->{$name})){
        my $sub=$form->{AJAX}->{$name};
        if($R && exists($R->{values})){
            $result=&{$sub}($s,$R->{values});
        }
        else{
            push @{$form->{errors}},qq{отсутствует параметр values}
        }
        
    }
    else{
        push @{$form->{errors}},"правило ajax $name не найдено!"
    }
    

    
    $s->print(
        $s->to_json({
            success=>scalar(@{$form->{errors}})?0:1,
            errors=>$form->{errors},
            result=>$result
        })
    )->end;
}



return 1;