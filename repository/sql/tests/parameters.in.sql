select id,company_name from companies where company_name=:companyName and status=@status and region=$region and id=$1 and owner_id=?;
