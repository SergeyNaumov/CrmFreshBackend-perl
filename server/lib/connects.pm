package connects;

sub get{
  [
    {
      name=>'crm_read',
      user=>'crm',
      host=>'localhost',
      dbname=>'crm'
    },
    {
      name=>'crm_write',
      user=>'crm',
      host=>'localhost',
      dbname=>'crm'
    },
    {
      name=>'toyota',
      user=>'toyota',
      host=>'localhost',
      dbname=>'toyota'
    },
  ];
};
return 1;
