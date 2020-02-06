package CRM::Ajax;
use utf8;
use strict;
use Data::Dumper;

sub process{
    
    my %arg=@_;
    my $form={errors=>[]};
    my $result;
    my $s=$arg{'s'};
    my $R=$s->request_content(from_json=>1);
    if($R && ref($R) eq 'HASH'){
        if($R->{id}=~m/^\d+$/){
            $arg{id}=$R->{id}
        }
        $form=CRM::read_conf(%arg);
        
        my $name=$arg{name};
        if(exists($form->{AJAX}->{$name})){
            my $sub=$form->{AJAX}->{$name};
            if($R->{values} && ref($R->{values}) eq 'HASH'){
                $result=&{$sub}($s,$R->{values});
            }
            else{
                push @{$form->{errors}},qq{отсутствует параметр values}
            }
        }
        else{
            push @{$form->{errors}},"правило ajax $name не найдено!"
        }
    }
    else{
        push @{$form->{errors}},'не переданы json-параметры'
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