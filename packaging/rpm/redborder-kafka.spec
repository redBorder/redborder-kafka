Name: redborder-kafka
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: Package for redborder containing kafka files

License: AGPL 3.0
URL: https://github.com/redBorder/redborder-common
Source0: %{name}-%{version}.tar.gz

Requires: bash 

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/usr/lib/redborder/bin
install -D -m 0755 resources/bin/rb_kafka_start.sh %{buildroot}/usr/lib/redborder/bin/rb_kafka_start.sh
install -D -m 0644 resources/systemd/kafka.service %{buildroot}/usr/lib/systemd/system/kafka.service

%files
%defattr(0644,root,root)
/usr/lib/systemd/system/kafka.service

%changelog
* Mon Jul 27 2016 Enrique Jimenez <ejimenez@redborder.com>  - 1.0.0-1
- first spec version
