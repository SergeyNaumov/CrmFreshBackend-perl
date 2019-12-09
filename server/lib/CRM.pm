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
    #{"left_menu":[{"target":null,"icon":"","id":"85","sort":"1","child":[{"url":"","type":"vue","params":"{\"config\":\"manager_menu\"}","header":"Меню CRM","target":null,"icon":"fa fa-address-book","id":"94","child":[{"url":"","header":"zz","params":"","type":"","icon":"","target":null,"path":"/94","child":[],"parent_id":"94","sort":"0","permission_id":null,"id":"106"}],"sort":"0","path":"/85","parent_id":"85","permission_id":null}],"parent_id":null,"path":"","permission_id":null,"url":"","type":"не выбрано","params":"","header":"CRM"},{"child":[{"url":"","header":"Новости","params":"{\"config\":\"news\"}","type":"vue","icon":"fa fa-newspaper","target":null,"permission_id":null,"child":[],"parent_id":"129","sort":"0","path":"/129","id":"130"},{"icon":"","target":null,"parent_id":"129","child":[],"path":"/129","sort":"0","permission_id":null,"id":"131","url":"","header":"Страны","params":"{\"config\":\"country\"}","type":"vue"},{"icon":"","target":null,"child":[],"path":"/129","parent_id":"129","sort":"0","permission_id":null,"id":"132","url":"","header":"Регионы","params":"","type":""}],"parent_id":null,"path":"","sort":"2","permission_id":null,"id":"129","icon":"","target":null,"params":"","header":"Контент","type":"","url":""}],"title":"CRM Digital Strateg","copyright":"copyright 2019 svcomplex","manager":{"id":"1","gone":"0","gone_date":"0000-00-00","current_role":"112","email":"","mobile_phone":"","group_id":"22","photo":"","login_tel":"","re_id":"0","born":"","login":"admin","phone_dob":"","enabled":"1","name":"Admin","phone":""},"errors":[]}
    # Иконки material-design: https://material.io/resources/icons/?icon=settings_ethernet&style=baseline


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