use utf8;
use strict;
use Data::Dumper;
sub select_managers_ids_from_perm{
  my $form=shift; my $perm=shift; my $s=$Work::engine;
  #my $sth=$s->{db}->prepare( select_from_table_perm($perm) );
  #$sth->execute();
  return [
        map {$_->{id} }
        @{
            $s->{db}->query(query=>select_from_table_perm($perm))
        }
    ];
          
}
sub select_managers_ids_from_perm{
  my $form=shift; my $perm=shift; my $s=$Work::engine;
  
  
  return [
    map {$_->{id} }
    @{
        $s->{db}->query(query=>select_from_table_perm($perm))
    }
];
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
return 1;