#/bin/bash

date=`date +%Y-%m-%d`
annee=`date +%Y`
mois=`date +%m`
jour=`date +%d`

source configTransformation.sh

# Paramètre 1 : le chemin absolu du répertoire où les zips ont été téléchargés
zips=$1

mkdir -p $racine


echo -e "\033[1m\n\nMise en lecture seule des ZIPs et décompression des fichiers XML vers l'historique...\033[0m"

echo -e "Répertoire courant (*.zip) : $zips"
cd $zips
ls -1 *.zip
chmod 444 *.zip
mkdir -p $racine/historiqueXML/$date
unzip -q '*.zip' -d $racine/historiqueXML/$date

echo -e "\033[1m\n\nCopie des fichiers XML vers un dossier temporaire...\033[0m"

echo -e "Répertoire courant (racine) : $racine"
cd $racine

if [ ! -d temp ]; then
    mkdir temp
fi

cp -rv historiqueXML/$date/* temp/

echo -e "\033[1m\n\nDéplacement des fichiers ZIP vers l'historique ZIP...\033[0m"

mkdir -p historiqueZIP/$date
mv -v $zips/*.zip historiqueZIP/$date

echo -e "\033[1m\n\nRéencodage en UTF-8 et transformation des fichiers XML...\033[0m"

cd temp
vides=0
pasvides=0
for xml in `find -path **/*.xml`
do
    if [ -s $xml ]; then
        echo -e "$xml : réencodage et transformation"
        java -jar $saxonJar -s:$xml -xsl:$xsltDir/decpDGFIP.xsl racine="$racine"
        ((pasvides++))
    else
        echo -e "$xml : fichier vide"
        ((vides++))
    fi
done

total=$((pasvides + vides))
echo -e "\nFichiers traités : $pasvides Fichiers vides : $vides Total : $total"

echo -e "\033[1m\n\nFusion et validation des fichiers XML par SIRET...\033[0m"

cd $racine

sirets=`ls sirets/$annee/$mois/$jour`

echo -e "\nSIRETs de la session :"
ls -1 sirets/$annee/$mois/$jour
echo ""

for siret in $sirets
do
    cd xml/$siret/$annee/$mois/$jour
    pwd
    for xml in `ls *.xml`
    do
        nouveauFichier=${xml/__*/.xml}
        java -jar $saxonJar -s:$xml -xsl:$xsltDir/merge.xsl > $nouveauFichier
        java -jar $validatorJar -sf $schemas/paquet.xsd -if $nouveauFichier
        break
    done
    ls -l
    cd $racine
done

echo -e "\033[1m\n\nFusion et dédoublonnage des données urlProfilAcheteur...\033[0m"
mkdir -p $racine/profilsAcheteurs
sort `ls $racine/sirets/$annee/$mois/$jour/*` | uniq > $racine/profilsAcheteurs/profilsAcheteurs-$date.csv
