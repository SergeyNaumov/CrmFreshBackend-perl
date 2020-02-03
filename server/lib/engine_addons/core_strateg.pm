package core_strateg;
use Data::Dumper;
use utf8;
use strict;
#use Exporter 'import';
#use Template;
#use MIME::Lite;
#use MIME::Base64;
#our @EXPORT_OK = qw/print_error pre print_header print_template html_strip send_mes/;
sub get_manager{
  my %arg=@_;
  my @where=(); my $m; my @values=();
  if($arg{login}=~m/.+/){
    push @where,'m.login = ?';
    push @values,$arg{login};
  }
  if($arg{id}=~m/^\d+$/){
    push @where, qq{m.id = $arg{id}};
  }
  if(!$arg{id} && !$arg{login}){
    die('need argument login or argument id');
  }
  my $sth=$arg{connect}->prepare(q{
    SELECT 
      m.*
    FROM
      manager m LEFT JOIN manager_group mg ON (m.group_id = mg.id)
    WHERE 
      }.join(' AND ',@where)
  );
  $sth->execute(@values);
  $m=$sth->fetchrow_hashref();
  if($m){
    @{$m->{CHILD_GROUPS}}=child_groups(connect=>$arg{connect},group_id=>$m->{group_id}) if($arg{child_groups});
    $sth=$arg{connect}->prepare(q{
      SELECT
        p.id, p.pname
      FROM
        manager_permissions mp JOIN permissions p ON (p.id=mp.permissions_id)
      WHERE mp.manager_id=?
    });
    $sth->execute($m->{id});
    while(my ($id,$pname)=$sth->fetchrow()){
          $m->{permissions}->{$pname}=$id;
	  }
  }
  #$m->{options}=[grep {/\S/} split /;+/,$m->{options}];
  return $m;
}

=cut
Возвращает список дочерних групп:
  child_groups(connect=>$dbh,group_id=>42)
=cut
sub child_groups{
  my %arg=@_;
  my @list=();
  my $where;
  # my @values=();
  #&::pre({arg=>\%arg});
  unless(ref($arg{group_id}) eq 'ARRAY'){
    $arg{group_id}=[$arg{group_id}]
  }
  $where=' parent_id IN ('.join(',',(grep /^\d+$/,@{$arg{group_id}})).')';
    
  my $sth=$arg{connect}->prepare("SELECT id from manager_group where $where");
  $sth->execute();
  #push @list,$arg{group_id}+0;
  while(my $id=(0+$sth->fetchrow())){
      push @{$arg{group_id}},child_groups(connect=>$arg{connect},group_id=>[$id+0]);
  }
  return @{$arg{group_id}};
}

sub get_owner{ # get_owner(dbh=>$dbh,cur_manager=>$manager,alien_owner=>[01]);
  # alian_owner -- если менеджер сам руководитель -- подниматься до вышестоящего
  my %arg=@_; my $dbh=$arg{connect}; my $cur_manager=$arg{cur_manager};
  my $path=$cur_manager->{group_path}.'/'.$cur_manager->{group_id};
  my $sth=$dbh->prepare("SELECT m.* from manager m JOIN manager_group mg ON (m.id=mg.owner_id) where mg.id=? and m.id>0");
  
  foreach (reverse grep /^\d+$/,split(/\//,$path)){
    
    $sth->execute($_);
    my $r=$sth->fetchrow_hashref;
    next unless($r);
    next if($arg{alien_owner} && $r->{id}==$cur_manager->{id});
    if($r){
      return $r;
    }
  }
  return undef;
}

sub get_cur_role {
  my %arg=@_;
  my $sth=$arg{connect}->prepare(q{
      SELECT m2.login
      FROM
        manager m   JOIN manager_role mr ON (m.id = mr.manager_id)
        JOIN manager m2  ON (m2.id = mr.role AND m.current_role = m2.id)
      WHERE m.login=?
    });
    $sth->execute($arg{login});
  my $r=$sth->fetchrow();
  $sth->finish;
  return ($r?$r:$arg{login})
}

sub select_from_table_perm{
  my $perm=shift;
  return 'select '.
            'm.id,m.name '.
          'FROM '.
            'manager m '.
            'join manager_permissions mp ON (mp.manager_id=m.id) '.
            'join permissions p ON (p.id=mp.permissions_id) '.
          q{WHERE pname='}.$perm.q{' }.
          'UNION '.
          'select '.
            'm.id,m.name '.
          'FROM '.
            'manager m '.
            'join manager_group_permissions mgp ON (mgp.group_id=m.group_id) '.
            'join permissions p ON (p.id=mgp.permissions_id) '.
          q{WHERE pname='}.$perm.q{'}
}

sub select_managers_from_perm{
  my $form=shift;
  my $perm=shift;

  my $sth=$form->{connects}->{strateg_read}->prepare( select_from_table_perm($perm) );
  $sth->execute();
  return $sth->fetchall_arrayref({});
          
}

sub select_managers_ids_from_perm{
  my $form=shift;
  my $perm=shift;

  my $sth=$form->{connects}->{strateg_read}->prepare( select_from_table_perm($perm) );
  $sth->execute();
  return [map {$_->{id} } @{$sth->fetchall_arrayref({})}];
          
}

sub select_managers_from_perm_optimizator{
  my $form=shift;
  my $perm=shift;
  my $sth=$form->{connects}->{strateg_read}->prepare(q{
    select 
      m.id,m.name,m.email
    FROM 
      manager m 
      join manager_optimization_permissions mp ON (mp.manager_id=m.id) 
      join optimization_permissions p ON (p.id=mp.permissions_id)
  WHERE pname=? }
  );
  $sth->execute($perm);
  return $sth->fetchall_arrayref({});
          
}

return 1;
END { }
