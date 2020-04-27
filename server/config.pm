package config;
sub get{
  return 
  {
      title=>'CRM Digital',
      copyright=>'copyright 2005 - {{cur_year}}',
      encrypt_method=>'mysql_encrypt', 
      system_email=>'noreply@digitalstrateg.ru',
      connects=>{
          crm_read=>{
              user=>'crm',
              host=>'localhost',
              dbname=>'crm',
              engine=>'mysql'
          },
          crm_write=>{
              user=>'crm',
              host=>'localhost',
              dbname=>'crm',
              engine=>'mysql'
          }
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
