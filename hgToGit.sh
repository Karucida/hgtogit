#!/bin/bash -x
start=`date +%s`

#ANTES HAY QUE EJECUTAR ESTOS COMANDOS LA PRIMERA VEZ PARA PASARNOS LA CLAVE A ROOT USANDO LA MISMA PASSPHRASSE
# ssh-add ~/.ssh/id_rsa
# sudo -E xxxxx para poder mantener la clave
#exit

#Hay que correrlo con el comando sudo -E ej
#sudo -E ./hgToGit.sh <username> <password> <mercurialSite> <gitSite:port>
#sudo -E ./hgToGit.sh cperez 1234 mercurial.com git.com:29418
#Sin http
#SI QUEREMOS QUE MUESTRE EN PANTALLA Y ESCRIBE LOG HAY QUE EJECUTAR EL COMANDO CON:
#sudo -E ./hgToGit.sh <username> <password> <mercurialSite> <gitSite:port> 2>&1 | tee SomeFile.txt

#Si falla el push por timeout lo mejor es usar este script
#es necesario estar en la branch¡
#https://docs.aws.amazon.com/codecommit/latest/userguide/how-to-push-large-repositories.html#how-to-push-large-repositories-sample


rootPath=$(pwd);

username=$1
password=$2
mercurialSite=$3
#sitiogit:xxxx con el puerto
gitSite=$4

echo "`date`-($repository)-  Usuario $mercurialSite"
echo "`date`-($repository)-  Sitio de git $mercurialSite"
echo "`date`-($repository)-  Sitio de git $gitSite"

echo "`date`-($repository)-  Te has autenticado con $username"
if [ ! -d "$rootPath/hg" ]; then
	echo "`date`-($repository)-  Creamos la carpeta hg $rootPath/hg"
	mkdir "$rootPath/hg"
fi
if [ ! -d "$rootPath/git" ]; then
	echo "`date`-($repository)-  Creamos la carpeta git $rootPath/git"
	mkdir "$rootPath/git"
fi

if [ ! -d "$rootPath/branches" ]; then
	echo "`date`-($repository)-  Creamos la carpeta de las ramas $rootPath/branches"
	mkdir "$rootPath/branches"
fi

cd "$rootPath/hg"
echo "`date`-($repository)-  cd $rootPath/hg"

listRepo=$rootPath/hgrepositories.txt
urlHgRepo=http://$username:$password@$mercurialSite

#Descargamos todos los repositorios que queramos convertir de un archivo
echo "`date`-($repository)-  Descargamos de $urlHgRepo"
if test -f "$listRepo"; then		echo "`date`-($repository)-  Exportamos las ramas"
		while IFS= read -r repo; do
echo "`date`-($repository)-  Clonamos $repo"
echo "`date`-($repository)-  hg clone $urlHgRepo/$repo"
hg clone $urlHgRepo/$repo

		done < $listRepo

chown -R "$username:$username" $rootPath/hg
chmod -R 775 $rootPath/hg
fi

for directory in */ ; do
    #QUITAMOS EL / será el repositorio
 repository=${directory%/}
    echo "`date`-($repository)-  Repositorio $repository"

    directory_git=$rootPath/git/$repository
    echo "`date`-($repository)-  Ruta GIT $directory_git"
    directory_hg=$rootPath/hg/$repository
    echo "`date`-($repository)-  Ruta HG $directory_hg"
    hgrc=$directory_hg/.hg/hgrc
    echo "`date`-($repository)-  Ruta al hgrc $hgrc"
    cd $directory_hg



	if [ ! -d "$directory_git" ]; then
		echo "`date`-($repository)-  Creamos la carpeta del directorio git $directory_git"
		mkdir "$directory_git"
		cd $directory_git
		echo "`date`-($repository)-  Iniciamos el git"
		git init
		echo "`date`-($repository)-  Añadimos el origen"
		git remote add origin ssh://git@$gitSite/unassigned/$repository.git
		echo "`date`-($repository)-  modificamos el tamaño máximo del fichero"
	fi

	echo "`date`-($repository)-  modificamos el tamaño máximo del fichero a subir"
	# subo de 500megas a 2gb por tamaños de repo
	git config http.postBuffer 2097152000

	#Comprobamos la configuración del hgrc si tiene la configuración necesaria
	if grep -q hgext.bookmarks "$hgrc"; then
			echo "`date`-($repository)-  El archivo tiene la configuración"
	else
    	cd $directory_hg/.hg/
		echo "`date`-($repository)-  Guardamos el suffix de bookmarks"
		sudo echo "# Linea de script hgToGit" >> "$hgrc"
		#sudo echo "`date`-($repository)-  [ui]" >> "$hgrc"
		sudo echo "username=$username" >> "$hgrc"
		sudo echo "[extensions]" >> "$hgrc"
		sudo echo "hgext.bookmarks =" >> "$hgrc"
		echo "`date`-($repository)-  Ponemos el rootPath de hggit: ${rootPath}/hg-git/hggit"
		sudo echo "hggit = ${rootPath}/hg-git/hggit" >> "$hgrc"
		sudo echo "[git]" >> "$hgrc"
		sudo echo "branch_bookmark_suffix=_bookmark" >> "$hgrc"	

		sudo chown -R "$username:$username" $rootPath/hg
    	sudo chmod -R 775 $rootPath/hg
	fi

	if grep -q x.prefix "$hgrc"; then
			echo "`date`-($repository)-  El archivo tiene los credenciales"
	else
		cd $directory_hg/.hg/

		echo "`date`-($repository)-  Guardamos los credenciales"
		userPrefix=$username@
		echo "`date`-($repository)-  Quitamos ${userPrefix} del prefix "
		prefixWithUser=$(grep -- "default =" hgrc | cut -d "=" -f2)
		prefixWithoutUser=$(echo "${prefixWithUser}" | sed "s/$userPrefix//g") 
		echo "`date`-($repository)-  El prefix es $prefixWithoutUser"
		sudo echo "[auth]" >> "$hgrc"
		sudo echo "x.prefix = $prefixWithoutUser" >> "$hgrc"
		sudo echo "x.username = $username" >> "$hgrc"
		sudo echo "x.password = $password" >> "$hgrc"
	fi
    
    cd $directory_hg
    
	hg pull

	#PUSHEAMOS LOS CAMBIOS
	#echo "`date`-($repository)-  PUSHEAMOS LOS CAMBIOS"
	#hg push $directory_git

    #Obtenemos en un fichero todas las ramas
    echo "`date`-($repository)-  Obtenemos en un fichero todas las ramas"
    hg log | grep "branch" | grep -v "summary" | sort --unique > "$rootPath/branches/$repository.txt" 

    input="$rootPath/branches/$repository.txt"

    #quitamos el branch:
    echo "`date`-($repository)-  Quitamos el branch:"
    sed -e s/branch://g -i $input
	#quitamos el bookmark:
    echo "`date`-($repository)-  Quitamos el bookmark:"
    sed -e s/bookmark://g -i $input

	chown -R "$username:$username" $directory_git/.git
    chmod -R 777 $directory_git

    lastBranch="default"
    hg bookmarks -r default "default_bookmark"
	if [ -s $input ]; then
		echo "`date`-($repository)-  Exportamos las ramas"


		echo "`date`-($repository)-  hg bookmarks -r default default_bookmark"
		while IFS= read -r branch; do
			#QUITAMOS LOS ESPACIOS
			branch=$(echo "${branch}" | sed -e 's/^[[:space:]]*//')
			branch_accent=$(echo "${branch}" | sed -e 'y/āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛ:./aaaaeeeeiiiioooouuuuüüüüAAAAEEEEIIIIOOOOUUUUUUUU__/')
			branch_under=$(echo "${branch_accent}" | sed -e 's/ /_/g')
			echo "`date`-($repository)-  $branch"
			echo "`date`-($repository)-  hg bookmarks -r $branch ${branch_under}_bookmark"
		    hg bookmarks -r "$branch" "${branch_under}_bookmark"
		    lastBranch=${branch}
		done < $input

    fi

	echo "`date`-($repository)-  Exportamos las bookmarks a ramas git"
	hg push $directory_git

    echo "`date`-($repository)-  Borramos los .lock"	

	find $directory_hg/.hg/git/refs/tags/ -maxdepth 1 -type f -name "*.lock" -delete	
	find $directory_hg/.hg/git/refs/heads/ -maxdepth 1 -type f -name "*.lock" -delete		
	find $directory_hg/.hg/git/refs/objects/ -maxdepth 1 -type f -name "*.lock" -delete	

    #cp -R $directory_hg/.hg/git $directory_git/.git

    echo "Copiamos refs/heads"
    cp -R $directory_hg/.hg/git/refs/heads $directory_git/.git/refs

	echo "Copiamos objects"
	cp -R $directory_hg/.hg/git/objects $directory_git/.git
	
	echo "`date`-($repository)-  Ponemos los permisos al directorio GIT $directory_git"

	chown -R "$username:$username" $directory_git
	chmod -R 775 $directory_git

    cd $directory_git

	#git push --set-upstream git@$gitSite/unassigned/$repository.git $lastBranch
    #Volvemos a poner el origen por si hay errores
	#git remote set-url origin ssh://git@$gitSite/unassigned/$repository.git

	echo "`date`-($repository)-  Pusheamos branches y commits"
	#git push origin --all
	#LIMITAMOS LA SUBIDA A PETICION SE SISTEMAS
	trickle -s -u 2048 git push --set-upstream origin --all
	echo "`date`-($repository)-  Pusheamos tags"
	#git push origin --tags
	#LIMITAMOS LA SUBIDA A PETICION SE SISTEMAS
	trickle -s -u 2048 git push --set-upstream origin --tags
    	#statements
done

end=`date +%s`

runtime=$((end-start))

echo "Tiempo de ejecución $runtime"
