Name: redborder-kafka
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: Package for redborder containing kafka files

License: AGPL 3.0
URL: https://github.com/redBorder/redborder-kafka
Source0: %{name}-%{version}.tar.gz

BuildRequires: systemd

Requires: bash java confluent-kafka-2.11

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/usr/lib/redborder/scripts
mkdir -p %{buildroot}/usr/lib/redborder/bin
install -D -m 0755 resources/bin/rb_kafka_start.sh %{buildroot}/usr/lib/redborder/bin/rb_kafka_start.sh
install -D -m 0755 resources/bin/rb_kafka_stop.sh %{buildroot}/usr/lib/redborder/bin/rb_kafka_stop.sh
install -D -m 0755 resources/bin/rb_delete_topics.sh %{buildroot}/usr/lib/redborder/bin/rb_delete_topics.sh
install -D -m 0755 resources/bin/rb_consumer.sh %{buildroot}/usr/lib/redborder/bin/rb_consumer.sh
install -D -m 0755 resources/bin/rb_producer.sh %{buildroot}/usr/lib/redborder/bin/rb_producer.sh
install -D -m 0644 resources/systemd/kafka.service %{buildroot}/usr/lib/systemd/system/kafka.service
cp resources/scripts/*.rb %{buildroot}/usr/lib/redborder/scripts
chmod 0755 %{buildroot}/usr/lib/redborder/scripts/*

%files
%defattr(0755,root,root)
/usr/lib/redborder/bin/rb_kafka_start.sh
/usr/lib/redborder/bin/rb_kafka_stop.sh
/usr/lib/redborder/bin/rb_delete_topics.sh
/usr/lib/redborder/bin/rb_consumer.sh
/usr/lib/redborder/bin/rb_producer.sh
/usr/lib/redborder/scripts
%defattr(0644,root,root)
/usr/lib/systemd/system/kafka.service

%post
/usr/lib/redborder/bin/rb_rubywrapper.sh -c

%systemd_post kafka.service

%changelog
* Fri Aug 26 2016 Carlos J Mateos <cjmateos@redborder.com> 1.0.0-1
- Added stop script for systemd unit file
* Tue Jul 28 2016 Enrique Jimenez <ejimenez@redborder.com> 1.0.0-1
- Changed permissions for kafka script
- Enabled systemd service in postinst
- Added confluent-kafka-2.11 as dependency
- first spec version
