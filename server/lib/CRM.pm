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

# хак для Data::Dumper + utf8
$Data::Dumper::Useqq = 1;
$Data::Dumper::Useperl = 1;
{ no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
}
$Data::Dumper::Terse=1;
# хак для Data::Dumper + utf8

our $s; my $form;

sub get_startpage{
    my $s=$Work::engine;
    #$s->pre($s->{db})->end; return;
    my $errors=[];
    my $left_menu;
    my ($manager_menu_table);
    my $manager;
    if($s->{config}->{use_project}){
      $manager=$s->{db}->query(
        query=>'select *,concat("/edit_form/project_manager/",id) link from project_manager where project_id=? and login=?',
        values=>[$s->{project}->{id}, $s->{login}],onerow=>1
      );
    }
    else{
      $manager=$s->{db}->query(query=>'select *,concat("/edit_form/manager/",id) link from manager where login=?',values=>[$s->{login}],onerow=>1);
      $manager->{permissions}=$s->{db}->query(query=>'SELECT permissions_id from manager_permissions where manager_id=?',values=>[$manager->{id}],massive=>1);
    }

    if($s->{config}->{use_project}){
      $manager_menu_table='project_manager_menu';
      $left_menu=$s->{db}->query(
        query=>'SELECT * from '.$manager_menu_table.' where parent_id is null order by sort',
        errors=>$errors,
        tree_use=>1
      );
    }
    else{

      my $perm_str='0';
      if( scalar(@{$manager->{permissions}}) ){
        $perm_str=join(',',@{$manager->{permissions}})
      }
      $left_menu=$s->{db}->query(
        query=>q{
          SELECT
            mm.*,group_concat(concat(mmp.permission_id,':',denied) SEPARATOR ';') perm
          from
            manager_menu mm
            LEFT JOIN manager_menu_permissions mmp ON mmp.menu_id=mm.id
          where
            mm.parent_id is null AND  
            (
              mmp.id is null
                OR 
              (mmp.denied=0 and mmp.permission_id in (}.$perm_str.q{) )
                OR
              (mmp.denied=1 and mmp.permission_id not in (}.$perm_str.q{) ) 
            )
          GROUP BY mm.id
          ORDER BY mm.sort
        },
        errors=>$errors,
        tree_use=>1
      );

      my $manager_menu_permissions
    }
    if($s->{config}->{menu}){
      $left_menu=$s->{config}->{menu};
    }
    else{


    }

    
    my $cur_year=cur_year();
    $s->{config}->{copyright}=~s/\{cur_year\}/$cur_year/g;

    
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

  if(
      (defined($form->{make_delete}) && !$form->{make_delete}) || 
      $form->{read_only}
    ){
    push @{$form->{errors}},'Удаление запрещено!'
  }

  if(!errors($form)){
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

      if($form->{work_table_foreign_key} && $form->{work_table_foreign_key_value}){
        unless(
          $form->{db}->query(
            query=>"select count(*) from $form->{work_table} WHERE $form->{work_table_id}=? and $form->{work_table_foreign_key}=?",
            values=>[$form->{id},$form->{work_table_foreign_key_value}],
            onevalue=>1
          )
        ){
          push @{$form->{errors}},'действие запрещено. запрещённый foreign_key. обратитесь к разработчику'
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
  }

  $s->print_json({
    success=>scalar(@{$form->{errors}})?0:1,
    errors=>$form->{errors},
    log=>$form->{log}
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