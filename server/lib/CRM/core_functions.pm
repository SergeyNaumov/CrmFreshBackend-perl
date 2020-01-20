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
sub to_translit{
    ($_)=@_;
    Encode::_utf8_on($_);
    {
      
      use utf8
      #
      # Fonetic correct translit
      #
      s/Сх/Sh/; s/сх/sh/; s/СХ/SH/;
      s/Ш/Sh/g; s/ш/sh/g;

      s/Сцх/Sch/; s/сцх/sch/; s/СЦХ/SCH/;
      s/Щ/Sch/g; s/щ/sch/g;

      s/Цх/Ch/; s/цх/ch/; s/ЦХ/CH/;
      s/Ч/Ch/g; s/ч/ch/g;

      s/Йа/Ja/; s/йа/ja/; s/ЙА/JA/;
      s/Я/Ja/g; s/я/ja/g;

      s/Йо/Jo/; s/йо/jo/; s/ЙО/JO/;
      s/Ё/Jo/g; s/ё/jo/g;

      s/Йу/Ju/; s/йу/ju/; s/ЙУ/JU/;
      s/Ю/Ju/g; s/ю/ju/g;

      #s/Э/E\'/g; s/э/e\'/g;
      s/Э/E/g; s/э/e/g;
      s/Е/E/g; s/е/e/g;

      s/Зх/Zh/g; s/зх/zh/g; s/ЗХ/ZH/g;
      s/Ж/Zh/g; s/ж/zh/g;
      s/[ьЬъЪ]//g;
      tr/
      абвгдзийклмнопрстуфхцъыьАБВГДЗИЙКЛМНОПРСТУФХЦЪЫЬ/
      abvgdzijklmnoprstufhc\"y\'ABVGDZIJKLMNOPRSTUFHC\"Y\'/;
    };
    
    return $_;
}

return 1;