package config;
my $year=(localtime(time))[3]+1900;
sub get{
  return 
  {
      title=>'CRM Digital',
      copyright=>"copyright 2005 - $year",
      encrypt_method=>'mysql_encrypt', 
      system_email=>'noreply@digitalstrateg.ru',
      connects=>{
          crm_read=>{
              user=>'yabikupil',
              host=>'localhost',
              dbname=>'yabikupil',
              engine=>'mysql'
          },
          crm_write=>{
              user=>'yabikupil',
              host=>'localhost',
              dbname=>'yabikupil',
              engine=>'mysql'
          }
      },
      controllers=>{
        left_menu=>'/left-menu'
      },
      docpack=>{
        user_table=>'user',
        docpack_foreign_key=>'user_id'
      },
      const=>{
          project_id=>''
      },

      events=>[
          'quiz'
      ]
  }
}

return 1;
