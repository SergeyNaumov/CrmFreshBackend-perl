$parser={
  title=>'Парсер CDEK',
  work_table=>'cdek_in_comp',
  tmp_dir=>'./tmp/parse-cdek',
  livetime_tmp=>'3600',# время жизни временных файлов
  before_loopback=>sub{ # собстве
    my $data=shift;
    unless($data->{manager_id}=~m/^\d+$/){
      $data->{manager_id}=0;
    }

  },
  fields=>[
    {name=>'header',description=>'Наименование'},
    {name=>'inn',description=>'ИНН'},
    {name=>'email',description=>'Почта'},
    {name=>'site',description=>'Сайт'},
    {name=>'phone',description=>'Телефон'},
    {name=>'manager_id',description=>'ID менеджера'}
  ]
};
# create table cdek_in_comp(
#   id int unsigned primary key auto_increment,
#   header varchar(512) not null default '',
#   inn varchar(12) not null default '',
#   email varchar(200) not null default '',
#   site varchar(200) not null default '',
#   phone varchar(200) not null default ''
# ) engine=innodb default charset=utf8;