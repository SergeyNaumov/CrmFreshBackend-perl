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
    my $manager=get_permissions_for(
      login=>$s->{login},
      's'=>$s
    );
    #print Dumper($manager);
    #my $manager=$s->{db}->query(query=>'select * from manager where login=?',values=>[$s->{login}],onerow=>1);
    #delete $manager->{password};
    my $left_menu=$s->{db}->query(
         query=>'
         SELECT
            m.*,group_concat( concat(mmp.denied,":",p.pname) SEPARATOR ";") permissions
         FROM
            manager_menu m
            LEFT JOIN manager_menu_permissions mmp ON (mmp.menu_id=m.id)
            LEFT JOIN permissions p ON (mmp.permission_id=p.id)
        WHERE
            m.parent_id is null
            GROUP BY m.id
        order by m.sort',
         errors=>$errors,
         tree_use=>1
    );
    #print Dumper($left_menu);
    $left_menu=hide_not_permit_items($left_menu,$manager->{permissions});
    my $cur_year=cur_year();
    $s->{config}->{copyright}=~s/\{cur_year\}/$cur_year/g;

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

sub hide_not_permit_items{
  my $menu=shift; my $permissions=shift; 
  my $list=[];
  foreach my $m (@{$menu}){
      my $m_perm=$m->{permissions};
      my $make_show=0;
      if($m_perm){
        
        foreach my $p (split(/;/,$m_perm)){
          my ($denied,$pname)=split(/:/,$p);
          if($denied && !$permissions->{$pname}){
            $make_show=1; last;
          }
          elsif($permissions->{$pname}){
            $make_show=1; last;
          }

          #print "make_show: $make_show\n";
        }
      }
      else{
        $make_show=1;
      }
      
      if($make_show){

        if($m->{child} && scalar(@{$m->{child}})){
          $m->{child}=hide_not_permit_items($m->{child},$permissions)
        }
        push @{$list},$m;
      }

  }
  return $list;
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