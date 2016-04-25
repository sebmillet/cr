
# Cryptographie pratique

## Introduction

### Pourquoi un tel document

Faire des calculs à la main sur des signatures électroniques est très ludique.

Il faut s'entendre sur le terme "à la main". Au fil du document nous ne ferons aucun calcul à la main ni même avec une calculatrice de bureau. Les nombres manipulés sont beaucoup trop grands.
Même à supposer que l'on décide d'utiliser une calculatrice de bureau (la chose est sans doute possible, en transférant les données depuis un PC), il faudrait la programmer en raison du nombre d'étapes de calcul.

### Contenu

Cet article décrit les calculs à faire pour vérifier des signatures RSA et ECDSA, dans le cadre x509 et 2D-Doc.

**RSA, ECDSA**

> _RSA_ et _ECDSA_ permettent de signer footnote:[_RSA_ permet également de chiffrer.]
> avec une paire de clés privée et publique.
> La clé privée est utilisée pour signer. La clé publique permet de vérifier la signature.

_Nous examinerons trois cas de signatures électroniques :_

1. _RSA_ dans le contexte x509 : cas du certificat d'un serveur https
2. _ECDSA_ dans le contexte x509 : création d'un certificat x509 auto-signé, afin de se familiariser avec les calculs sur les courbes elliptiques
3. _ECDSA_ dans le contexte 2D-Doc : vérification d'un code 2D-Doc, qui est le standard du Certificat Électronique Visible

_Au fil du document nous ferons appel aux outils suivants :_

* _openssl_ pour travailler sur les certificats x509 en ligne de commande
* _pkfile_ pour extraire la partie signée d'un certificat et _dder_ pour afficher certains contenus binaires
* _python_ ou _bc_ pour faire des calculs avec des nombres entiers de grande taille
* Conversion entre encodage _PEM_ et encodage _binaire_ (Linux : _base64_, Windows : _notepad++_)
* Édition de contenu de fichier binaire (Linux : _gvim/xxd_, Windows : _notepad++_)

| NOTE |
| --- |
| _Windows versus Linux_ |
| Ce document s'adresse aux utilisateurs de Windows et Linux. |
|  |
| Il peut arriver que l'outil ou la commande à employer diffère entre les deux environnements, dans ce cas les deux sont présentés. |

* * *

## Le format x509

### Visualisation d'un certificat x509

A l'aide d'un navigateur, ouvrir une page en https et afficher le certificat.
Les exemples de ce document sont réalisés avec le certificat https du site https://letsencrypt.org/.

_Exemple avec Firefox 44_

1. Cliquer sur l'icône de cadenas à gauche de la barre d'adresse et cliquer sur la flèche droite (Figure 1)
2. Cliquer sur _Plus d'informations_ (Figure 2)
3. Cliquer sur _Afficher le certificat_ (Figure 3)
4. Afficher l'onglet _Détails_ et parcourir les différents champs du certificat (Figure 4, 5 et 6)

![Fig. 1](./images/img-firefox-1-redim.png)

![Fig. 2](./images/img-firefox-2-redim.png)

![Fig. 3](./images/img-firefox-3-redim.png)

![Fig. 4](./images/img-firefox-4-redim.png)

![Fig. 5](./images/img-firefox-5-redim.png)

![Fig. 6](./images/img-firefox-6-redim.png)

Nous nous intéresserons à la partie supérieure (_Hiérarchie des certificats_) plus tard.

Pour le moment examinons le certificat. L'affichage de Firefox en dessous de _Champs du certificat_ liste trois parties :

1. Le certificat proprement dit, qui contient beaucoup d'informations structurées sur plusieurs niveaux hiérarchiques
2. L'algorithme de signature du certificat, dans notre exemple, _PKCS #1 SHA-256 avec chiffrement RSA_
3. La signature du certificat, ici, une suite de 256 octets

Cette structure en trois parties est toujours respectée pour un certificat x509.
A noter qu'Internet Explorer et Chrome affichent les mêmes informations mais sans faire ressortir la structure trois parties.

### Structure d'un certificat x509

Où la structure d'un certificat est-elle définie, et quelle est cette définition ?

Une recherche sur un moteur de recherche avec les mots-clés _RFC_ et _x509_ produit l'URL suivante dans les premières réponses :

https://tools.ietf.org/html/rfc5280

Et effectivement lafootnote:[Nous utiliserons le féminin dans ce document. RFC étant un acronyme anglais, il n'y a pas d'argument définitif pour l'emploi du masculin ou du féminin.]
*RFC 5280* définit le format x509 version 3.

Affichons-la. Dans la section _4.1_ se trouve la définition suivante.

```
...
4.1.  Basic Certificate Fields

   The X.509 v3 certificate basic syntax is as follows.  For signature
   calculation, the data that is to be signed is encoded using the ASN.1
   distinguished encoding rules (DER) [X.690].  ASN.1 DER encoding is a
   tag, length, value encoding system for each element.

Certificate  ::=  SEQUENCE  {
	tbsCertificate       TBSCertificate,
	signatureAlgorithm   AlgorithmIdentifier,
	signatureValue       BIT STRING  }
...
```

La suite définit les différents éléments du certificat, à savoir _TBSCertificate_ et _AlgorithmIdentifier_.

