package CRM;
use lib './lib/CRM';
use Routine;
use AdminTableFind;
use AdminTableFilters;
use EditForm;
use Memo;
use OneToM;
use ReadConf;
use strict;
use utf8;
use Data::Dumper;
use experimental 'smartmatch';
use core_functions;
no warnings 'experimental::smartmatch';

our $s; my $form;

sub get_startpage{
    my $s=$Work::engine;
    #$s->pre($s->{db})->end; return;
    my $errors=[];
    my $left_menu=$s->{db}->query(
         query=>'SELECT * from manager_menu where parent_id is null order by sort',
         errors=>$errors,
         tree_use=>1
    );

    my $cur_year=cur_year();
    $s->{config}->{copyright}=~s/\{cur_year\}/$cur_year/g;
    my $manager=$s->{db}->query(query=>'select * from manager where login=?',values=>[$s->{login}],onerow=>1);
    delete $manager->{password};
    return $s->to_json(
        {
            title=>$s->{config}->{title},
            copyright=>$s->{config}->{copyright},
            left_menu=>$left_menu,
            errors=>$errors,
            success=>scalar(@{$errors})?0:1,
            manager=>$manager
        }
    );
}

sub get_result{
    my $s=$Work::engine;
    $s->print_header({'content-type'=>'text/html'});
    my $R=$s->request_content();
    if($R){
        $R=$s->from_json($R);
    }

    admin_table_find($R);
}

#sub process_form{
#
#    processEditForm(@_);
#}
sub process_memo{
  my %arg=@_; my $s=$arg{'s'};
  
  if($arg{action} eq 'get'){
    get_memo(@_);
  }
  elsif($arg{action} eq 'add'){
    add_to_memo(@_);
  }
  elsif($arg{action} eq 'delete'){
    delete_from_memo(@_);
  }
  elsif($arg{action} eq 'update'){
    update_memo(@_);
  }
  
}

sub process_1_to_m{
  my %arg=@_; my $s=$arg{'s'};
  $arg{form}=read_conf(config=>$arg{config},script=>$arg{script},id=>$arg{id});
  OneToM::process(%arg);
}
sub delete_element{
  my %arg=@_; my $s=$arg{'s'};
  my $form=read_conf(%arg);

  run_event(
      event=>$form->{events}->{before_delete},
      description=>'events->before_delete',
      form=>$form
  );
  foreach my $f  (@{$form->{fields}}){
    if($f->{before_delete}){
        run_event(
            event=>$f->{before_delete},description=>'field: $f->{name} event: before_delete',form=>$form
        );
    }
  }
  if(!errors($form)){
    $form->{db}->query(
      query=>qq{DELETE FROM $form->{work_table} WHERE $form->{work_table_id}=$form->{id}},
      errors=>$form->{errors},
    );
  }

  if(!errors($form)){
    run_event(
        event=>$form->{events}->{after_delete},
        description=>'events->after_delete',
        form=>$form
    );
  }
  foreach my $f  (@{$form->{fields}}){
    if($f->{after_delete}){
        if(!errors($form)){
          run_event(
              event=>$f->{after_delete},description=>'field: $f->{name} event: after_delete',form=>$form
          );
        }
    }
  }
  $s->print_json({
    success=>errors($form)?0:1,
    errors=>$form->{errors}
  })->end;
}
sub datetime{
  my $t=shift;
  $t=time() unless($t);
  
  my ($d,$m,$y,$hour,$min,$sec)=(localtime($t))[3,4,5,2,1,0];
  return sprintf("%04d-%02d-%02d %02d:%02d:%02d",$y+1900,$m+1,$d,$hour,$min,$sec);
}
sub cur_date{ # возвращает тек. дату с учётом дельты
  my $delta=shift; $delta=0 unless($delta);
  my ($d,$m,$y)=(localtime(time()+$delta*86400))[3,4,5];
  return sprintf("%04d-%02d-%02d",$y+1900,$m+1,$d);
}
sub get_child_field{
  my %arg=@_;
  foreach my $f (@{$arg{fields}}){
    if($f->{name} eq $arg{name}){
        return $f;
    }
  }
}
return 1;